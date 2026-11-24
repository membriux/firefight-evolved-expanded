using System;
using System.Collections.Generic;
using System.IO;

namespace FireFightEvolved.HscCompile
{
    internal sealed class Options
    {
        public List<string> HscFiles = new List<string>();
        public string MapPath;
        public string ScriptingXml;
        public string FormatsDir;
        public string BuildString;
        public string ObjectsFile;
        public string ReportPath;
        public bool Write;
        public bool AllowXmlMismatch;
        public bool OverwriteBackup;
        public bool ShowHelp;
        // --load-only: load <map> through Blamite and report whether the reference
        // implementation accepts it. No .hsc, no scripting XML, no write. This is the
        // mandatory gate every writer output has to pass (research/19 §8.2).
        public bool LoadOnly;
        public int MaxErrors = 200;
        public string Dialect = "auto";
        public bool Unit;

        public static Options Parse(string[] args)
        {
            var o = new Options();
            for (int i = 0; i < args.Length; i++)
            {
                string a = args[i];
                string Next(string name)
                {
                    if (i + 1 >= args.Length) throw new ArgumentException(name + " needs a value");
                    return args[++i];
                }

                switch (a)
                {
                    case "--hsc": o.HscFiles.Add(Path.GetFullPath(Next(a))); break;
                    case "--map": o.MapPath = Path.GetFullPath(Next(a)); break;
                    case "--xml": o.ScriptingXml = Path.GetFullPath(Next(a)); break;
                    case "--formats": o.FormatsDir = Path.GetFullPath(Next(a)); break;
                    case "--build": o.BuildString = Next(a); break;
                    case "--objects": o.ObjectsFile = Path.GetFullPath(Next(a)); break;
                    case "--report": o.ReportPath = Path.GetFullPath(Next(a)); break;
                    case "--max-errors": o.MaxErrors = int.Parse(Next(a)); break;
                    case "--dialect": o.Dialect = Next(a); break;
                    case "--unit": o.Unit = true; break;
                    case "--load-only": o.LoadOnly = true; break;
                    case "--write": o.Write = true; break;
                    case "--dry-run": o.Write = false; break;
                    case "--allow-xml-mismatch": o.AllowXmlMismatch = true; break;
                    case "--overwrite-backup": o.OverwriteBackup = true; break;
                    case "-h":
                    case "--help": o.ShowHelp = true; break;
                    default:
                        if (a.StartsWith("-")) throw new ArgumentException("unknown option " + a);
                        o.HscFiles.Add(Path.GetFullPath(a));
                        break;
                }
            }

            if (o.LoadOnly)
            {
                if (o.MapPath == null)
                    throw new ArgumentException("--load-only needs --map <cache.map>");
                if (o.HscFiles.Count > 0)
                    throw new ArgumentException("--load-only takes no .hsc input");
                return o;
            }

            if (!o.ShowHelp && o.HscFiles.Count == 0)
                throw new ArgumentException("no input: give at least one --hsc <file.hsc>");
            return o;
        }

        public static void PrintUsage(TextWriter w)
        {
            w.WriteLine(@"hsc-compile - compile a HaloScript .hsc into a Halo: Reach MCC cache's scnr
             script tables, on macOS, using Blamite from Assembly-CrossPlatform.

USAGE
  hsc-compile --hsc <file.hsc> [--hsc <file.hsc>...] --xml <Scripting.xml>
              [--map <cache.map> | --build ""<build string>""]
              [--formats <dir>] [--objects <manifest>] [--report <file>]
              [--write [--overwrite-backup]] [--allow-xml-mismatch]
              [--unit] [--dialect auto|assembly] [--max-errors N]
  hsc-compile --load-only --map <cache.map> [--formats <dir>]

MODES
  (default)   DRY RUN. Parses, lints and compiles. Writes nothing.
  --write     Commit the compiled script tables to the map. Needs a --map, a clean
              compile, and either one --hsc or --unit. Copies the map to <map>.bak
              first and refuses if that file already exists.
  --load-only Load <map> through Blamite and exit 0 only if it loads: dumps the
              segment/area table, then reads every language pack so the locale
              pointers are resolved too. No .hsc, no XML, nothing written. This is
              the gate for anything tools/map/reach_write.py produces - our own
              reader accepting a cache is not evidence that it is well formed.
              Set BLAMITE_SEGMENT_DUMP=1 to also print every FileSegmenter
              DefineSegment call and the full table at a size violation.

INPUTS
  --map       Target Reach MCC cache. Read-only unless --write is given.
  --build     Build string to compile against when no map is available
              (e.g. ""Jun 21 2023 15:35:31""). Lint and compile still run; script
              object resolution is meaningless without a cache or --objects.
  --xml       Scripting definition XML. MUST be byte-identical to the one
              Engines.xml assigns to the cache's build string, or the run is
              refused: a mismatched opcode table yields wrong bytecode silently.
  --formats   <checkout>/src/Blamite/Formats. Defaults to $BLAMITE_FORMATS.
  --objects   Manifest of script objects that are expected to pre-exist in the
              scenario, used to synthesise a scripting context. One per line:
                  ai_squad:sq_fe_marines
                  object_name:terminal_01
                  ai_squad:sq_fe_marines/ai_group_location:cell_01
              Blamite's compiler can only REFERENCE script objects, never add
              them, so this manifest is a to-do list for Sapien/Foundation, not
              a substitute for one.

  --dialect   auto (default) rewrites script-declaration headers from the
              Bungie/HEK source dialect into the one Blamite's HS_Gen1 grammar
              accepts: a mandatory return type, and the script name outside any
              parentheses with one comma-separated parameter list. Only the
              declaration line changes, so diagnostic line numbers still match
              the file on disk. 'assembly' disables the rewrite.

  --unit      Concatenate every --hsc, in the order given, into ONE compile unit.
              Blamite rebuilds the whole script table from the text it is handed,
              so this is the only shape a real write can take: the unit must be
              the map's complete script, not a fragment. Diagnostics still name
              the original file and line.

EXIT CODES
  0 ok   1 compile failure   2 bad arguments   3 refused (build/xml mismatch)");
        }
    }
}
