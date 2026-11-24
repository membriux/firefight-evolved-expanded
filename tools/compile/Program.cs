// hsc-compile - macOS HaloScript compile driver for Halo: Reach MCC caches.
//
// Pipeline (modelled on Assembly's ScriptEditor.xaml.cs:406-440):
//   lexer -> HS_Gen1Parser.hsc() -> scriptFile.LoadContext -> new ScriptCompiler(...)
//   -> ParseTreeWalker.Walk -> SaveScripts
//
// Dry run is the default. Writing requires --write and always takes a .bak first.
// See README.md in this directory.

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using System.Xml.Linq;
using Antlr4.Runtime;
using Antlr4.Runtime.Tree;
using Blamite.Blam;
using Blamite.Blam.Scripting;
using Blamite.Blam.Scripting.Compiler;
using Blamite.Blam.Scripting.Context;
using Blamite.IO;
using Blamite.Serialization;
using Blamite.Serialization.Settings;

namespace FireFightEvolved.HscCompile
{
    internal static class Program
    {
        private static readonly StringBuilder Report = new StringBuilder();

        private static void Say(string line)
        {
            Console.WriteLine(line);
            Report.AppendLine(line);
        }

        private static int Main(string[] rawArgs)
        {
            // Blamite's StringTable.Write calls EndianWriter.WriteWin1252, which is
            // Encoding.GetEncoding(1252). .NET 8 does not carry the legacy code pages, so
            // SaveScripts throws NotSupportedException("No data is available for encoding 1252")
            // AFTER it has already started writing - which leaves a half-written cache.
            // Registering the provider here is the whole fix; see HscCompile.csproj.
            System.Text.Encoding.RegisterProvider(
                System.Text.CodePagesEncodingProvider.Instance);

            Options opt;
            try
            {
                opt = Options.Parse(rawArgs);
            }
            catch (ArgumentException ex)
            {
                Console.Error.WriteLine("argument error: " + ex.Message);
                Console.Error.WriteLine();
                Options.PrintUsage(Console.Error);
                return 2;
            }

            if (opt.ShowHelp)
            {
                Options.PrintUsage(Console.Out);
                return 0;
            }

            int exit;
            try
            {
                exit = Run(opt);
            }
            catch (Exception ex)
            {
                Say("FATAL: " + ex.GetType().Name + ": " + ex.Message);
                Say(ex.StackTrace ?? "");
                exit = 1;
            }

            if (opt.ReportPath != null)
            {
                Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(opt.ReportPath)));
                File.WriteAllText(opt.ReportPath, Report.ToString());
                Console.Error.WriteLine("report written: " + opt.ReportPath);
            }

            return exit;
        }

        private static string Trim(string s, int max)
        {
            s = (s ?? "").Replace("\r", " ").Replace("\n", " ");
            return s.Length <= max ? s : s.Substring(0, max) + "...";
        }

        // Names the segments the FileSegmenter dump prints as bare offsets, so a dump pair
        // can be read as "which declared size overruns which neighbour".
        private static void DumpAreas(ICacheFile cache)
        {
            void Seg(string name, FileSegment s)
            {
                if (s == null) { Say(string.Format("[area] {0,-22} (absent)", name)); return; }
                Say(string.Format("[area] {0,-22} offset=0x{1:X8} size=0x{2:X8} actual=0x{3:X8} end=0x{4:X8}",
                    name, s.Offset, s.Size, s.ActualSize, s.Offset + s.ActualSize));
            }
            void Group(string name, FileSegmentGroup g)
            {
                if (g == null) { Say(string.Format("[area] {0,-22} (absent)", name)); return; }
                Say(string.Format("[area] {0,-22} offset=0x{1:X8} size=0x{2:X8} basePointer=0x{3:X8} segments={4}",
                    name, g.Offset, g.Size, g.BasePointer, g.Segments.Count));
                for (int i = 0; i < g.Segments.Count; i++)
                    Seg(name + "[" + i + "]", g.Segments[i]);
            }

            Say(string.Format("[area] file size             0x{0:X8}", cache.FileSize));
            Group("MetaArea(tag)", cache.MetaArea);
            Seg("RawTable(resource)", cache.RawTable);
            Group("StringArea(debug)", cache.StringArea);
            Group("LocaleArea", cache.LocaleArea);
            if (cache.Partitions != null)
                for (int i = 0; i < cache.Partitions.Length; i++)
                    Say(string.Format("[area] partition {0,-12} basePointer=0x{1:X8} size=0x{2:X8}",
                        i, cache.Partitions[i].BasePointer == null ? 0 : cache.Partitions[i].BasePointer.AsPointer(),
                        cache.Partitions[i].Size));
        }

        private static int Run(Options opt)
        {
            // ---------------------------------------------------------------- formats
            string formats = opt.FormatsDir ?? Environment.GetEnvironmentVariable("BLAMITE_FORMATS");
            if (string.IsNullOrEmpty(formats))
            {
                Say("ERROR: no Formats directory. Pass --formats <dir> or set BLAMITE_FORMATS.");
                Say("       It is <checkout>/src/Blamite/Formats of an Assembly-CrossPlatform clone.");
                return 2;
            }
            formats = Path.GetFullPath(formats);
            string enginesXml = Path.Combine(formats, "Engines.xml");
            if (!File.Exists(enginesXml))
            {
                Say("ERROR: " + enginesXml + " not found.");
                return 2;
            }

            Say("hsc-compile  (Blamite / Assembly-CrossPlatform, net8.0, " + RuntimeTriple() + ")");
            Say("formats      : " + formats);

            // Engines.xml stores its database paths relative to the process working
            // directory, so the driver must run from the directory that holds Formats.
            // Every path from the command line has already been made absolute.
            Directory.SetCurrentDirectory(Path.GetDirectoryName(formats));

            EngineDatabase db = XMLEngineDatabaseLoader.LoadDatabase(enginesXml);

            // ---------------------------------------------------------------- cache
            ICacheFile cache = null;
            EngineDescription buildInfo = null;
            FileStreamManager streams = null;
            string buildString;

            if (opt.MapPath != null)
            {
                string map = Path.GetFullPath(opt.MapPath);
                if (!File.Exists(map))
                {
                    Say("ERROR: map not found: " + map);
                    return 2;
                }
                streams = new FileStreamManager(map, Endian.LittleEndian);
                using (IReader r = streams.OpenRead())
                    cache = CacheFileLoader.LoadCacheFile(r, map, db, out buildInfo);

                buildString = cache.BuildString;
                Say("map          : " + map);
                Say("cache        : engine=" + cache.Engine + " build=\"" + buildString + "\""
                    + " internalName=" + cache.InternalName
                    + " tags=" + cache.Tags.Count + " groups=" + cache.TagGroups.Count);

                if (opt.LoadOnly)
                {
                    DumpAreas(cache);
                    // Reading locale strings resolves the localization section's own pointers
                    // against the file, which is what tag-area growth used to break: if the
                    // localization data moved but its pointers did not follow, the strings come
                    // back empty or garbage even when the header still looks plausible.
                    int langs = 0, total = 0;
                    string sample = null;
                    using (IReader lr = streams.OpenRead())
                    {
                        foreach (var lang in cache.Languages.AvailableLanguages)
                        {
                            var pack = cache.Languages.LoadLanguage(lang, lr);
                            if (pack == null) continue;
                            langs++;
                            foreach (var list in pack.StringLists)
                            {
                                total += list.Strings.Count;
                                if (sample == null && list.Strings.Count > 0)
                                    sample = list.Strings[0].Value;
                            }
                        }
                    }
                    Say("locales      : " + langs + " language pack(s), " + total
                        + " string(s), first = " + (sample == null ? "(none)" : "\"" + Trim(sample, 48) + "\""));
                    Say("LOAD: OK - Blamite accepts this cache.");
                    return 0;
                }
            }
            else
            {
                if (opt.BuildString == null)
                {
                    Say("ERROR: give --map <cache.map>, or --build \"<build string>\" for a map-less lint.");
                    return 2;
                }
                buildString = opt.BuildString;
                buildInfo = db.FindEngineByBuild(buildString);
                if (buildInfo == null)
                {
                    Say("ERROR: no engine in Engines.xml has build=\"" + buildString + "\".");
                    return 3;
                }
                Say("map          : (none - map-less lint)");
                Say("build        : \"" + buildString + "\" -> engine \"" + buildInfo.Name + "\"");
            }

            // ------------------------------------------------- scripting XML build guard
            // A scripting XML from the wrong MCC update compiles to confidently wrong
            // opcodes, so this is a hard gate.
            string expectedXml = ResolveScriptingXmlForBuild(enginesXml, formats, buildString, out string engineName);
            if (expectedXml == null)
            {
                Say("ERROR: no engine in Engines.xml has build=\"" + buildString + "\".");
                Say("       The cache is not a build this Blamite checkout knows. Refusing to compile.");
                return 3;
            }
            Say("engine       : " + engineName);
            Say("expects xml  : " + expectedXml);

            if (opt.ScriptingXml == null)
            {
                Say("ERROR: --xml <scripting xml> is required. For this build it must be:");
                Say("       " + expectedXml);
                return 2;
            }
            string givenXml = Path.GetFullPath(opt.ScriptingXml);
            if (!File.Exists(givenXml))
            {
                Say("ERROR: scripting xml not found: " + givenXml);
                return 2;
            }

            string expectedHash = Sha256(expectedXml);
            string givenHash = Sha256(givenXml);
            Say("given xml    : " + givenXml);
            Say("xml sha256   : given=" + givenHash.Substring(0, 16) + " expected=" + expectedHash.Substring(0, 16));

            if (expectedHash != givenHash)
            {
                Say("");
                Say("REFUSING TO RUN: the scripting definition XML does not match the cache's build.");
                Say("  cache build     : \"" + buildString + "\"  (" + engineName + ")");
                Say("  that build needs: " + expectedXml);
                Say("  you supplied    : " + givenXml);
                Say("  A mismatched opcode table produces bytecode that is wrong but looks fine.");
                Say("  Override only if you know exactly why: --allow-xml-mismatch");
                if (!opt.AllowXmlMismatch)
                    return 3;
                Say("  --allow-xml-mismatch given: continuing under protest.");
            }
            else
            {
                Say("xml guard    : OK (byte-identical to the table this build requires)");
            }

            OpcodeLookup opcodes = buildInfo.ScriptInfo;
            if (opcodes == null)
            {
                Say("ERROR: engine \"" + engineName + "\" has no scripting database loaded.");
                return 3;
            }
            Say("opcodes      : " + opcodes.GetAllUniqueFunctionNames().Count() + " function names, "
                + opcodes.GetAllUniqueGlobalNames().Count() + " globals, "
                + opcodes.GetAllValueTypeNames().Count() + " value types");

            // ---------------------------------------------------------------- context
            ScriptingContextCollection context;
            string contextSource;
            if (cache != null)
            {
                IScriptFile scnrFile = cache.ScriptFiles?.FirstOrDefault(f => f is ScnrScriptFile);
                if (scnrFile != null)
                {
                    using (IReader r = streams.OpenRead())
                        context = scnrFile.LoadContext(r, cache);
                    contextSource = "cache scnr (" + scnrFile.Name + ")";
                }
                else
                {
                    context = new ScriptingContextCollection();
                    contextSource = "EMPTY - the cache exposes no scnr script file";
                }
            }
            else
            {
                context = new ScriptingContextCollection();
                contextSource = "EMPTY (map-less lint)";
            }

            if (opt.ObjectsFile != null)
            {
                int added = SyntheticContext.Load(context, opt.ObjectsFile);
                contextSource += " + " + added + " declared objects from " + opt.ObjectsFile;
            }

            var ctxObjects = context.GetAllContextObjects().ToList();
            Say("context      : " + contextSource);
            Say("             : " + ctxObjects.Count + " script objects in "
                + ctxObjects.Select(o => o.ObjectGroup).Distinct().Count() + " blocks");
            if (ctxObjects.Count == 0)
            {
                Say("WARNING      : the scripting context is empty. Every script-object reference");
                Say("             : (squads, object names, trigger volumes...) WILL be reported");
                Say("             : unresolved. Object-resolution results below are not meaningful");
                Say("             : until a real cache or an --objects manifest is supplied.");
            }

            // ---------------------------------------------------------------- per file
            int failed = 0;
            ScriptData lastGood = null;
            string lastGoodFile = null;

            // A compile unit is what one ScriptCompiler run sees. Blamite rebuilds the
            // ENTIRE script table from the text it is given, so a real write must present
            // the whole map's script in one unit. --unit concatenates the inputs for that;
            // otherwise each file is its own unit, which only ever works for a self
            // contained file.
            List<List<string>> units = opt.Unit
                ? new List<List<string>> { opt.HscFiles }
                : opt.HscFiles.Select(f => new List<string> { f }).ToList();

            foreach (List<string> unit in units)
            {
                Say("");
                Say("=====================================================================");
                Say(unit.Count == 1 ? "FILE: " + unit[0]
                                    : "UNIT: " + unit.Count + " files concatenated into one compile unit");
                foreach (string u in unit) if (unit.Count > 1) Say("      " + u);
                Say("=====================================================================");

                string missing = unit.FirstOrDefault(f => !File.Exists(f));
                if (missing != null)
                {
                    Say("ERROR: not found: " + missing);
                    failed++;
                    continue;
                }

                // line -> "file:line in that file"
                var owner = new List<Tuple<string, int>> { Tuple.Create("", 0) };  // 1-based
                var sb0 = new StringBuilder();
                foreach (string f in unit)
                {
                    string t = File.ReadAllText(f).Replace("\r\n", "\n");
                    string[] ls = t.Split('\n');
                    for (int li = 0; li < ls.Length; li++)
                        owner.Add(Tuple.Create(Path.GetFileName(f), li + 1));
                    sb0.Append(t);
                    if (!t.EndsWith("\n")) sb0.Append('\n');
                }
                string code = sb0.ToString();
                string hscPath = unit[unit.Count - 1];
                Func<int, string> loc = line =>
                    line >= 1 && line < owner.Count
                        ? owner[line].Item1 + ":" + owner[line].Item2.ToString(CultureInfo.InvariantCulture)
                        : "?:" + line.ToString(CultureInfo.InvariantCulture);

                Say(string.Format(CultureInfo.InvariantCulture,
                    "size: {0} bytes, {1} lines", code.Length, code.Split('\n').Length));

                // ---- 0. dialect normalisation (HEK/Sapien source -> Blamite HS_Gen1)
                if (opt.Dialect != "assembly")
                {
                    Dialect.Result norm = Dialect.Normalise(code, opcodes);
                    if (norm.Rewrites.Count > 0)
                    {
                        Say("");
                        Say("[dialect] " + norm.Rewrites.Count + " script declaration header(s) rewritten from the");
                        Say("          Bungie/HEK source dialect into the one Blamite's grammar accepts.");
                        Say("          Line numbers below still match the file on disk; columns may shift.");
                        Say("          Pass --dialect assembly to turn this off.");
                        foreach (string r in norm.Rewrites.Take(Math.Min(10, opt.MaxErrors)))
                            Say("          " + Regex.Replace(r, @"^line (\d+)",
                                mm => loc(int.Parse(mm.Groups[1].Value))));
                        if (norm.Rewrites.Count > 10)
                            Say("          ... " + (norm.Rewrites.Count - 10) + " more");
                        code = norm.Text;
                    }
                }

                // ---- 1. lexer + parser, collecting every syntax error
                var collector = new ParsingExceptionCollector();
                ICharStream stream = CharStreams.fromstring(code);
                var lexer = new HS_Gen1Lexer(stream);
                lexer.RemoveErrorListeners();
                lexer.AddErrorListener(collector);
                ITokenStream tokens = new CommonTokenStream(lexer);
                var parser = new HS_Gen1Parser(tokens);
                parser.RemoveErrorListeners();
                parser.AddErrorListener(collector);
                parser.BuildParseTree = true;
                HS_Gen1Parser.HscContext tree = parser.hsc();

                var syntaxErrors = collector.GetExceptions().ToList();
                Say("");
                Say("[parse] " + syntaxErrors.Count + " syntax error(s)");
                int shown = 0;
                foreach (ParsingExceptionInformation e in syntaxErrors)
                {
                    if (shown++ >= opt.MaxErrors) { Say("  ... " + (syntaxErrors.Count - opt.MaxErrors) + " more suppressed (--max-errors)"); break; }
                    Say(string.Format(CultureInfo.InvariantCulture, "  {0}:{1}: syntax: {2}",
                        loc(e.Line), e.Column, e.Message));
                }

                Say("");
                Say("[parse] top level: " + tree.scriptDeclaration().Length + " script declaration(s), "
                    + tree.globalDeclaration().Length + " global declaration(s)");

                if (syntaxErrors.Count > 0)
                {
                    Say("[parse] ABORT: the real compiler refuses any file with syntax errors");
                    Say("        (ScriptEditor.xaml.cs:427-431). Fix these first; the lint below");
                    Say("        is still run, but it walked a damaged tree.");
                }

                // ---- 2. static lint against the opcode table and the context
                var lint = new Linter(opcodes, context, tree, loc);
                lint.Run();
                lint.Emit(Say, opt.MaxErrors);

                // ---- 3. the real compiler. Fail-fast: it throws on the first defect.
                if (syntaxErrors.Count > 0)
                {
                    Say("");
                    Say("[compile] not attempted (syntax errors above)");
                    failed++;
                    continue;
                }

                string logPath = Path.Combine(Path.GetTempPath(),
                    "hsc-compile-" + Path.GetFileNameWithoutExtension(hscPath) + ".log");
                using (var logStream = File.Create(logPath))
                {
                    var listener = new TextWriterTraceListener(logStream);
                    var logger = new ScriptCompilerLogger(listener);
                    var progress = new NullProgress();
                    try
                    {
                        var sw = Stopwatch.StartNew();
                        var compiler = new ScriptCompiler(cache, buildInfo, opcodes, context, progress, logger, false);
                        ParseTreeWalker.Default.Walk(compiler, tree);
                        ScriptData data = compiler.Result();
                        sw.Stop();
                        listener.Flush();

                        if (data == null)
                        {
                            Say("");
                            Say("[compile] the walk finished but Result() was null - no bytecode produced.");
                            failed++;
                        }
                        else
                        {
                            Say("");
                            Say(string.Format(CultureInfo.InvariantCulture,
                                "[compile] OK in {0:0.000}s - BYTECODE PRODUCED: {1} expressions, {2} scripts, {3} globals, {4} tag references, {5} string bytes",
                                sw.Elapsed.TotalSeconds, data.Expressions.Count, data.Scripts.Count,
                                data.Globals.Count, data.TagReferences.Count, data.Strings.Size));
                            lastGood = data;
                            lastGoodFile = unit.Count == 1 ? hscPath : string.Join(" + ", unit.Select(Path.GetFileName));
                        }
                    }
                    catch (CompilerException ce)
                    {
                        listener.Flush();
                        Say("");
                        Say(string.Format(CultureInfo.InvariantCulture,
                            "[compile] FAILED at {0}:{1} near \"{2}\"",
                            loc(ce.Line), ce.Column, Truncate(ce.Text, 80)));
                        Say("[compile] " + ce.Message);
                        Say("[compile] compiler log: " + logPath);
                        Say("[compile] NOTE: the compiler aborts on the first defect. Fix it and re-run");
                        Say("          to see the next one. The [lint] list above is not fail-fast.");
                        failed++;
                    }
                    catch (Exception ex)
                    {
                        listener.Flush();
                        Say("");
                        Say("[compile] FAILED with " + ex.GetType().Name + ": " + ex.Message);
                        foreach (string frame in (ex.StackTrace ?? "").Split('\n').Take(4))
                            Say("[compile]   " + frame.Trim());
                        Say("[compile] compiler log: " + logPath);
                        if (cache == null)
                            Say("[compile] NOTE: no --map was given. Blamite's compiler dereferences the cache "
                                + "for string IDs and tag references, so a map-less run cannot get past the first "
                                + "string_id or tag argument. This is a limit of the map-less mode, not a defect "
                                + "in the script.");
                        failed++;
                    }
                }
            }

            // ---------------------------------------------------------------- write
            Say("");
            Say("=====================================================================");
            if (!opt.Write)
            {
                Say("DRY RUN - nothing was written to any map. Pass --write to commit.");
                Say(failed == 0 ? "RESULT: all files compiled." : "RESULT: " + failed + " of " + opt.HscFiles.Count + " file(s) did not compile.");
                return failed == 0 ? 0 : 1;
            }

            if (failed > 0 || lastGood == null)
            {
                Say("WRITE REFUSED: not every file compiled, so nothing is written.");
                return 1;
            }
            if (cache == null)
            {
                Say("WRITE REFUSED: --write needs --map.");
                return 2;
            }
            if (opt.HscFiles.Count > 1 && !opt.Unit)
            {
                Say("WRITE REFUSED: with several --hsc files, --write needs --unit. The compiler");
                Say("               rebuilds the whole script table from scratch, so writing each");
                Say("               file in turn would leave only the last one in the map.");
                return 2;
            }

            var scnr = cache.ScriptFiles?.FirstOrDefault(f => f is ScnrScriptFile);
            if (scnr == null)
            {
                Say("WRITE REFUSED: the cache exposes no scnr script file.");
                return 3;
            }

            string mapPath = Path.GetFullPath(opt.MapPath);
            string bak = mapPath + ".bak";
            if (File.Exists(bak) && !opt.OverwriteBackup)
            {
                Say("WRITE REFUSED: " + bak + " already exists. Move it, or pass --overwrite-backup.");
                return 2;
            }
            Say("backup       : " + mapPath + " -> " + bak);
            File.Copy(mapPath, bak, opt.OverwriteBackup);

            Say("writing      : " + lastGoodFile + " -> " + mapPath);
            using (IStream s = streams.OpenReadWrite())
            {
                scnr.SaveScripts(lastGood, s, new NullProgress());
                cache.SaveChanges(s);
            }
            Say("WROTE. Backup at " + bak + ".");
            Say("This compiler is not 100% accurate (Assembly's own warning). Verify in MCC");
            Say("with anti-cheat disabled before trusting the result.");
            return 0;
        }

        // ------------------------------------------------------------------ helpers

        private static string RuntimeTriple()
        {
            return System.Runtime.InteropServices.RuntimeInformation.OSDescription.Split(' ')[0]
                   + "/" + System.Runtime.InteropServices.RuntimeInformation.ProcessArchitecture
                   + " clr " + Environment.Version;
        }

        private static string Truncate(string s, int n)
        {
            if (s == null) return "";
            s = s.Replace("\r", " ").Replace("\n", " ");
            return s.Length <= n ? s : s.Substring(0, n) + "...";
        }

        private static string Sha256(string path)
        {
            using (var sha = SHA256.Create())
            using (var fs = File.OpenRead(path))
                return BitConverter.ToString(sha.ComputeHash(fs)).Replace("-", "").ToLowerInvariant();
        }

        /// <summary>
        /// Walks Engines.xml (following <c>inherits</c>) to find the scripting XML that this
        /// build string is defined to use. Returns null when no engine has that build.
        /// </summary>
        private static string ResolveScriptingXmlForBuild(string enginesXml, string formats,
            string buildString, out string engineName)
        {
            engineName = null;
            XDocument doc = XDocument.Load(enginesXml);
            var byName = new Dictionary<string, XElement>();
            foreach (XElement e in doc.Root.Elements("engine"))
            {
                string n = (string)e.Attribute("name");
                if (n != null) byName[n] = e;
            }

            XElement start = doc.Root.Elements("engine")
                .FirstOrDefault(e => (string)e.Attribute("build") == buildString);
            if (start == null) return null;
            engineName = (string)start.Attribute("name");

            XElement cur = start;
            var seen = new HashSet<string>();
            while (cur != null)
            {
                XElement scripting = cur.Element("databases")?.Elements("scripting").FirstOrDefault();
                if (scripting != null)
                {
                    string rel = (string)scripting.Attribute("path");
                    // Paths in Engines.xml are relative to the directory holding Formats.
                    string full = Path.GetFullPath(Path.Combine(Path.GetDirectoryName(formats), rel));
                    if (!File.Exists(full))
                        full = Path.GetFullPath(Path.Combine(formats, rel.Replace("Formats/", "")));
                    return full;
                }
                string parent = (string)cur.Attribute("inherits");
                if (parent == null || !seen.Add(parent)) break;
                byName.TryGetValue(parent, out cur);
            }
            return null;
        }
    }

    internal sealed class NullProgress : IProgress<int>
    {
        public void Report(int value) { }
    }
}
