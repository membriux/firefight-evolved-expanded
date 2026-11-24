using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using Blamite.Blam.Scripting;

namespace FireFightEvolved.HscCompile
{
    /// <summary>
    /// Normalises a script-declaration header from the Bungie/HEK source dialect into the
    /// dialect Blamite's HS_Gen1 grammar accepts.
    ///
    /// The two dialects are not compatible, and this is the single biggest obstacle to
    /// compiling HEK-authored HaloScript with Assembly:
    ///
    ///   HEK / Sapien source, and every shipped script under research/_raw/hsc:
    ///       (script continuous my_script
    ///       (script static void (my_script (long cost) (ai squad))
    ///
    ///   Blamite HS_Gen1 (grammar line 7, and what BlamScriptDecompiler emits):
    ///       (script continuous void my_script
    ///       (script static void my_script (long cost, ai squad)
    ///
    ///   scriptDeclaration : LP SCRIPT SCRIPTTYPE VALUETYPE scriptID scriptParameters? expression+ RP
    ///   scriptParameters  : LP parameter (',' parameter)* RP
    ///
    /// So the return type is mandatory for every script type, the name sits outside any
    /// parentheses, and the parameters are one comma-separated list.
    ///
    /// Both rewrites are confined to the declaration's own line, so LINE NUMBERS IN EVERY
    /// DIAGNOSTIC STILL MATCH THE ORIGINAL FILE. Columns on a rewritten line can shift by
    /// a few characters.
    /// </summary>
    internal static class Dialect
    {
        private static readonly Regex Header =
            new Regex(@"^(\s*)\(\s*script\s+(?<rest>.*)$", RegexOptions.Compiled);

        internal sealed class Result
        {
            public string Text;
            public List<string> Rewrites = new List<string>();
        }

        public static Result Normalise(string code, OpcodeLookup opcodes)
        {
            var scriptTypes = new HashSet<string>(opcodes.GetAllScriptTypeNames());
            var valueTypes = new HashSet<string>(opcodes.GetAllValueTypeNames());

            var res = new Result();
            string[] lines = code.Split('\n');

            for (int i = 0; i < lines.Length; i++)
            {
                string line = lines[i].TrimEnd('\r');
                Match m = Header.Match(line);
                if (!m.Success) continue;

                string indent = m.Groups[1].Value;
                string rest = m.Groups["rest"].Value;

                // The script type must be the first token, or this is not a declaration.
                var tok = Regex.Match(rest, @"^(?<t>[A-Za-z_][A-Za-z0-9_]*)\s*(?<tail>.*)$");
                if (!tok.Success) continue;
                string stype = tok.Groups["t"].Value;
                if (!scriptTypes.Contains(stype)) continue;
                string tail = tok.Groups["tail"].Value;

                var changes = new List<string>();

                // 1. Is there a return type?
                var rtok = Regex.Match(tail, @"^(?<t>[A-Za-z_][A-Za-z0-9_]*)\s*(?<tail>.*)$");
                string rtype;
                if (rtok.Success && valueTypes.Contains(rtok.Groups["t"].Value))
                {
                    rtype = rtok.Groups["t"].Value;
                    tail = rtok.Groups["tail"].Value;
                }
                else
                {
                    rtype = "void";
                    changes.Add("inserted the mandatory return type \"void\"");
                }

                // 2. Is the name wrapped in parentheses with HEK-style parameters?
                string name;
                string parameters = null;
                if (tail.StartsWith("("))
                {
                    int close = MatchParen(tail);
                    if (close < 0) continue;                       // not a one-line header
                    string wrapped = tail.Substring(1, close - 1).Trim();
                    string after = tail.Substring(close + 1);

                    var nm = Regex.Match(wrapped, @"^(?<n>[A-Za-z_0-9][A-Za-z0-9_]*)\s*(?<p>.*)$");
                    if (!nm.Success) continue;
                    name = nm.Groups["n"].Value;
                    string pbody = nm.Groups["p"].Value.Trim();

                    var ps = new List<string>();
                    foreach (Match pm in Regex.Matches(pbody,
                                 @"\(\s*(?<t>[A-Za-z_][A-Za-z0-9_]*)\s+(?<n>[A-Za-z_][A-Za-z0-9_]*)\s*\)"))
                        ps.Add(pm.Groups["t"].Value + " " + pm.Groups["n"].Value);

                    parameters = ps.Count > 0 ? "(" + string.Join(", ", ps) + ")" : null;
                    changes.Add(ps.Count > 0
                        ? "unwrapped the name and rewrote " + ps.Count + " parameter(s) as one comma-separated list"
                        : "unwrapped the parenthesised script name");
                    tail = after.Trim();
                }
                else
                {
                    var nm = Regex.Match(tail, @"^(?<n>[A-Za-z_0-9][A-Za-z0-9_]*)\s*(?<tail>.*)$");
                    if (!nm.Success) continue;
                    name = nm.Groups["n"].Value;
                    tail = nm.Groups["tail"].Value.Trim();
                }

                if (changes.Count == 0) continue;

                var sb = new StringBuilder();
                sb.Append(indent).Append("(script ").Append(stype).Append(' ').Append(rtype)
                  .Append(' ').Append(name);
                if (parameters != null) sb.Append(' ').Append(parameters);
                if (tail.Length > 0) sb.Append(' ').Append(tail);

                lines[i] = sb.ToString();
                res.Rewrites.Add(string.Format(CultureInfo.InvariantCulture,
                    "line {0}: {1} -> {2}", i + 1, string.Join("; ", changes), name));
            }

            res.Text = string.Join("\n", lines);
            return res;
        }

        /// <summary>Index of the ')' matching the '(' at position 0, or -1.</summary>
        private static int MatchParen(string s)
        {
            int depth = 0;
            for (int i = 0; i < s.Length; i++)
            {
                if (s[i] == '(') depth++;
                else if (s[i] == ')')
                {
                    depth--;
                    if (depth == 0) return i;
                }
            }
            return -1;
        }
    }
}
