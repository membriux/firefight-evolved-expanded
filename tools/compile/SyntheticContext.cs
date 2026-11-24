using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Blamite.Blam.Scripting.Context;

namespace FireFightEvolved.HscCompile
{
    /// <summary>
    /// Builds a <see cref="ScriptingContextCollection"/> from a plain-text manifest of
    /// script objects that are expected to pre-exist in the scenario.
    ///
    /// This exists for one reason: Blamite's ScriptCompiler can only REFERENCE script
    /// objects that the scenario already defines. It never creates one. A manifest lets
    /// a script be type-checked on a machine that has no usable cache, and doubles as
    /// the explicit list of content that must be authored in Sapien/Foundation first.
    ///
    /// Format, one entry per line, '#' or ';' starts a comment:
    ///     block:name
    ///     block:name/child_block:child_name
    /// Block names are the tag-block names in the engine's scnr_script_context layout:
    /// zone_set, object_name, device_group, starting_profile, trigger_volume,
    /// ai_squad_group, ai_squad (children ai_group_location, ai_single_location),
    /// point_set (child point_set_point), cutscene_flag, cutscene_camera_point,
    /// cutscene_title, folder, ai_objective (child ai_role), designer_zone,
    /// cinematic_lightprobe.
    /// </summary>
    internal static class SyntheticContext
    {
        public static int Load(ScriptingContextCollection target, string path)
        {
            // block -> name -> list of child (block, name)
            var blocks = new Dictionary<string, Dictionary<string, List<Tuple<string, string>>>>();

            foreach (string raw in File.ReadAllLines(path))
            {
                string line = raw;
                int cut = line.IndexOfAny(new[] { '#', ';' });
                if (cut >= 0) line = line.Substring(0, cut);
                line = line.Trim();
                if (line.Length == 0) continue;

                string[] steps = line.Split('/');
                Tuple<string, string> top = ParseStep(steps[0], path, raw);
                if (!blocks.TryGetValue(top.Item1, out var byName))
                {
                    byName = new Dictionary<string, List<Tuple<string, string>>>();
                    blocks[top.Item1] = byName;
                }
                if (!byName.TryGetValue(top.Item2, out var children))
                {
                    children = new List<Tuple<string, string>>();
                    byName[top.Item2] = children;
                }
                for (int i = 1; i < steps.Length; i++)
                    children.Add(ParseStep(steps[i], path, raw));
            }

            int added = 0;
            foreach (var block in blocks)
            {
                if (target.TryGetBlock(block.Key, out _))
                {
                    Console.Error.WriteLine("--objects: block \"" + block.Key + "\" already comes from the "
                        + "cache; Blamite offers no way to merge into it, so these entries are skipped.");
                    continue;
                }

                int index = 0;
                var objects = new List<ScriptingContextObject>();
                foreach (var entry in block.Value)
                {
                    var obj = new ScriptingContextObject(entry.Key, index++, block.Key, false);
                    foreach (var childGroup in entry.Value.GroupBy(c => c.Item1))
                    {
                        int ci = 0;
                        obj.AddChildBlock(new ScriptingContextBlock(childGroup.Key,
                            childGroup.Select(c => new ScriptingContextObject(c.Item2, ci++, childGroup.Key, true))
                                      .ToList()));
                    }
                    objects.Add(obj);
                    added++;
                }
                target.AddObjectGroup(new ScriptingContextBlock(block.Key, objects));
            }
            return added;
        }

        private static Tuple<string, string> ParseStep(string step, string path, string raw)
        {
            int colon = step.IndexOf(':');
            if (colon <= 0 || colon == step.Length - 1)
                throw new ArgumentException(path + ": expected \"block:name\", got \"" + raw.Trim() + "\"");
            return Tuple.Create(step.Substring(0, colon).Trim(), step.Substring(colon + 1).Trim());
        }
    }
}
