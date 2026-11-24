using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using Blamite.Blam.Scripting;
using Blamite.Blam.Scripting.Compiler;
using Blamite.Blam.Scripting.Context;

namespace FireFightEvolved.HscCompile
{
    /// <summary>
    /// A non-fail-fast companion to Blamite's ScriptCompiler.
    ///
    /// The real compiler throws a CompilerException on the FIRST defect it meets, which
    /// means one run surfaces one error. For a body of script that has never been near a
    /// compiler that is useless as a work list. This walks the same parse tree and the
    /// same OpcodeLookup the compiler uses, and reports EVERY instance of the four
    /// defect classes that can be decided statically:
    ///
    ///   1. unknown function / script name in call position
    ///   2. wrong argument count for a known function (checked against the real argc of
    ///      every overload in the scripting XML; variadic special forms are skipped)
    ///   3. unknown script type or value type in a declaration
    ///   4. script-object references that the scripting context cannot resolve
    ///
    /// It is deliberately NOT a type checker: full expression typing is what
    /// ScriptCompilerTypeHandling does, and duplicating it would just be a second,
    /// less correct implementation. Anything this misses, the compiler still catches.
    /// </summary>
    internal sealed class Linter
    {
        private readonly OpcodeLookup _opcodes;
        private readonly ScriptingContextCollection _context;
        private readonly HS_Gen1Parser.HscContext _tree;
        private readonly Func<int, string> _loc;

        // declared in this file
        private readonly Dictionary<string, int> _scriptArity = new Dictionary<string, int>();
        private readonly HashSet<string> _globals = new HashSet<string>();
        private readonly HashSet<string> _parameters = new HashSet<string>();

        private readonly List<Finding> _findings = new List<Finding>();
        private readonly Dictionary<string, ObjectNeed> _objectNeeds = new Dictionary<string, ObjectNeed>();

        /// <summary>
        /// Value types that name something the scenario must already contain. Taken from
        /// the engine's scnr_script_context layout and from the context lookups in
        /// ScriptCompilerTypeHandling. Value type -> candidate context block names.
        /// </summary>
        private static readonly Dictionary<string, string[]> ObjectTypeBlocks =
            new Dictionary<string, string[]>
            {
                { "ai",                   new[] { "ai_squad", "ai_squad_group", "ai_objective" } },
                { "object_name",          new[] { "object_name" } },
                { "unit_name",            new[] { "object_name" } },
                { "vehicle_name",         new[] { "object_name" } },
                { "weapon_name",          new[] { "object_name" } },
                { "device_name",          new[] { "object_name" } },
                { "scenery_name",         new[] { "object_name" } },
                { "effect_scenery_name",  new[] { "object_name" } },
                { "crate_name",           new[] { "object_name" } },
                { "device_group",         new[] { "device_group" } },
                { "trigger_volume",       new[] { "trigger_volume" } },
                { "zone_set",             new[] { "zone_set" } },
                { "cutscene_flag",        new[] { "cutscene_flag" } },
                { "cutscene_camera_point",new[] { "cutscene_camera_point" } },
                { "cutscene_title",       new[] { "cutscene_title" } },
                { "starting_profile",     new[] { "starting_profile" } },
                { "point_reference",      new[] { "point_set" } },
                { "folder",               new[] { "folder" } },
                { "designer_zone",        new[] { "designer_zone" } },
                { "cinematic_lightprobe", new[] { "cinematic_lightprobe" } },
            };

        public Linter(OpcodeLookup opcodes, ScriptingContextCollection context,
                      HS_Gen1Parser.HscContext tree, Func<int, string> locator)
        {
            _opcodes = opcodes;
            _context = context;
            _tree = tree;
            _loc = locator;
        }

        public void Run()
        {
            foreach (var g in _tree.globalDeclaration())
            {
                string name = g.ID()?.GetTextSanitized();
                if (name != null) _globals.Add(name);

                string vt = g.VALUETYPE()?.GetTextSanitized();
                if (vt != null && _opcodes.GetTypeInfo(vt) == null)
                    Add("unknown-value-type", g.Start.Line,
                        "global \"" + name + "\" declares value type \"" + vt + "\", which this build's scripting XML does not define");
            }

            foreach (var s in _tree.scriptDeclaration())
            {
                string name = s.scriptID()?.GetTextSanitized() ?? "<unnamed>";
                int arity = s.scriptParameters()?.parameter()?.Length ?? 0;
                if (!_scriptArity.ContainsKey(name))
                    _scriptArity[name] = arity;
                else
                    Add("duplicate-script", s.Start.Line,
                        "script \"" + name + "\" is declared more than once in this file");

                string st = s.SCRIPTTYPE()?.GetTextSanitized();
                if (st != null && _opcodes.GetScriptTypeOpcode(st) == 0xFFFF)
                    Add("unknown-script-type", s.Start.Line,
                        "script \"" + name + "\" has script type \"" + st + "\", which this build's scripting XML does not define");

                string rt = s.VALUETYPE()?.GetTextSanitized();
                if (rt != null && _opcodes.GetTypeInfo(rt) == null)
                    Add("unknown-value-type", s.Start.Line,
                        "script \"" + name + "\" returns \"" + rt + "\", which this build's scripting XML does not define");
            }

            foreach (var g in _tree.globalDeclaration())
            {
                _parameters.Clear();
                WalkExpression(g.expression());
            }
            foreach (var s in _tree.scriptDeclaration())
            {
                // A parameter name is not a script object and not a global. Track them
                // per declaration so references to them are not reported as unresolved.
                _parameters.Clear();
                var pl = s.scriptParameters()?.parameter();
                if (pl != null)
                    foreach (var p in pl)
                        if (p.ID() != null) _parameters.Add(p.ID().GetTextSanitized());

                foreach (var e in s.expression())
                    WalkExpression(e);
            }
            _parameters.Clear();
        }

        private void WalkExpression(HS_Gen1Parser.ExpressionContext e)
        {
            if (e == null) return;
            if (e.call() != null) WalkCall(e.call());
            else if (e.branch() != null)
            {
                foreach (var inner in e.branch().expression()) WalkExpression(inner);
            }
            else if (e.cond() != null)
            {
                foreach (var grp in e.cond().condGroup())
                    foreach (var inner in grp.expression()) WalkExpression(inner);
            }
            // bare literals carry no statically decidable defect without full typing
        }

        private void WalkCall(HS_Gen1Parser.CallContext call)
        {
            string name = call.callID().GetTextSanitized();
            var args = call.expression();
            int argc = args.Length;

            List<FunctionInfo> overloads = _opcodes.GetFunctionInfo(name);

            if (overloads == null || overloads.Count == 0)
            {
                if (_scriptArity.TryGetValue(name, out int declared))
                {
                    if (declared != argc)
                        Add("script-arity", call.Start.Line,
                            "script \"" + name + "\" takes " + declared + " parameter(s), called with " + argc);
                }
                else if (_globals.Contains(name))
                {
                    Add("global-called", call.Start.Line,
                        "\"" + name + "\" is a global, not a function; it cannot be called");
                }
                else
                {
                    Add("unknown-function", call.Start.Line,
                        "unknown function or script \"" + name + "\" - not in this build's scripting XML and not declared in this file");
                }
            }
            else
            {
                bool variadic = overloads.Any(f => !string.IsNullOrEmpty(f.Group));
                var exact = overloads.Where(f => (f.ParameterTypes?.Length ?? 0) == argc).ToList();

                if (!variadic && exact.Count == 0)
                {
                    string expected = string.Join("|", overloads
                        .Select(f => (f.ParameterTypes?.Length ?? 0).ToString(CultureInfo.InvariantCulture))
                        .Distinct());
                    Add("arity", call.Start.Line,
                        "\"" + name + "\" takes " + expected + " argument(s), called with " + argc);
                }

                if (!overloads.Any(f => f.Implemented))
                    Add("unimplemented", call.Start.Line,
                        "\"" + name + "\" is marked unimplemented in this build's scripting XML; the engine will not run it");

                // Record the script objects the arguments require.
                FunctionInfo chosen = exact.FirstOrDefault() ?? overloads[0];
                if (chosen.ParameterTypes != null)
                {
                    for (int i = 0; i < argc && i < chosen.ParameterTypes.Length; i++)
                        NoteObjectArgument(chosen.ParameterTypes[i], args[i]);
                }
            }

            foreach (var inner in args) WalkExpression(inner);
        }

        private void NoteObjectArgument(string paramType, HS_Gen1Parser.ExpressionContext arg)
        {
            if (paramType == null) return;

            // A tag-reference argument must be the tag's PATH as it appears in the
            // cache's file-name table, optionally suffixed ".<group>". Blamite resolves
            // it with Tags.FindTagByName and returns null - "Failed to process the
            // expression ... A <type> expression was expected" - for anything else.
            ScriptValueType vt = _opcodes.GetTypeInfo(paramType);
            if (vt != null && vt.TagGroup != null)
            {
                var tagLit = arg.literal();
                var tagId = tagLit?.ID();
                if (tagId != null)
                {
                    string t = tagId.GetTextSanitized();
                    if (t != "none" && !_parameters.Contains(t) && !_globals.Contains(t)
                        && t.IndexOf('\\') < 0 && t.IndexOf('/') < 0 && t.IndexOf('.') < 0)
                    {
                        Add("tagref-not-a-path", arg.Start.Line,
                            "\"" + t + "\" is used where a " + paramType + " TAG REFERENCE is expected; "
                            + "the compiler needs the tag's full path from the cache's file-name table "
                            + "(group " + vt.TagGroup + "), not a short name");
                    }
                }
                return;
            }

            if (!ObjectTypeBlocks.TryGetValue(paramType, out string[] blocks)) return;

            var lit = arg.literal();
            var id = lit?.ID();
            if (id == null) return;                       // a call, a number, or none
            string name = id.GetTextSanitized();
            if (name == "none" || _globals.Contains(name) || _parameters.Contains(name)) return;

            // "sq_x/cell" and "obj_x/role" address a child of the named object.
            string[] parts = name.Split('/');
            string head = parts[0];

            bool resolved = blocks.Any(b => _context.ContainsObject(Tuple.Create(b, head)));
            string key = paramType + "\u0000" + name;
            if (!_objectNeeds.TryGetValue(key, out ObjectNeed need))
            {
                need = new ObjectNeed
                {
                    ParamType = paramType,
                    Name = name,
                    Blocks = blocks,
                    Resolved = resolved,
                    FirstLine = arg.Start.Line
                };
                _objectNeeds[key] = need;
            }
            need.Uses++;
        }

        private void Add(string kind, int line, string message)
        {
            _findings.Add(new Finding { Kind = kind, Line = line, Message = message });
        }

        public void Emit(Action<string> say, int maxErrors)
        {
            say("");
            say("[lint] " + _findings.Count + " static finding(s) (not fail-fast - every instance is listed)");

            foreach (var group in _findings.GroupBy(f => f.Kind).OrderByDescending(g => g.Count()))
                say("       " + group.Count().ToString(CultureInfo.InvariantCulture).PadLeft(5) + "  " + group.Key);

            int shown = 0;
            foreach (Finding f in _findings.OrderBy(f => f.Line))
            {
                if (shown++ >= maxErrors)
                {
                    say("  ... " + (_findings.Count - maxErrors) + " more suppressed (--max-errors)");
                    break;
                }
                say(string.Format(CultureInfo.InvariantCulture, "  {0}: {1}: {2}",
                    _loc(f.Line), f.Kind, f.Message));
            }

            var needs = _objectNeeds.Values.ToList();
            var missing = needs.Where(n => !n.Resolved).ToList();
            say("");
            say("[objects] " + needs.Count + " distinct script-object reference(s); "
                + missing.Count + " unresolved against the current context");
            foreach (var byType in missing.GroupBy(n => n.ParamType).OrderBy(g => g.Key))
            {
                say("  " + byType.Key + " (looked up in: " + string.Join(", ", byType.First().Blocks) + ")");
                foreach (var n in byType.OrderBy(n => n.Name))
                    say("    " + n.Name + "   (first use " + _loc(n.FirstLine) + ", " + n.Uses + " use(s))");
            }
        }

        private sealed class Finding
        {
            public string Kind;
            public int Line;
            public string Message;
        }

        private sealed class ObjectNeed
        {
            public string ParamType;
            public string Name;
            public string[] Blocks;
            public bool Resolved;
            public int FirstLine;
            public int Uses;
        }
    }
}
