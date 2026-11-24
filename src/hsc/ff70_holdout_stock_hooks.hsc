; =====================================================================================================
;  ff70_holdout_stock_hooks.hsc  -  the ONLY edits the stock Holdout script needs.
;
;  Compile this file ONLY inside the full unit, after the map's own 377-script decompile.  It touches
;  stock globals, so it cannot compile standalone and must never be fed to the compiler on its own.
;
;  UNIT ORDER FOR THE REAL WRITE:
;    build/holdout/unit/fe_culled_shims.hsc      (restores the culled `player_count` script)
;    build/holdout/unit/stock_unescaped.hsc      (the map's own 377 scripts / 205 globals)
;    src/hsc/fe_reinforcements.hsc               (the purchase library)
;    src/hsc/ff70_holdout.hsc                    (the six kiosks)
;    src/hsc/ff70_holdout_stock_hooks.hsc        (this file)
;
;  WHY THIS FILE EXISTS.  The purchase system reuses sq_sur_drop_01..04 as the ally squads, because
;  they are the only squads in Holdout that already carry a populated cell and spawn points.  Stock
;  Holdout also uses them, as ENEMIES, in its drop-pod event: drop_pod_01..04 do
;  (object_create "dm_drop_0N") then (ai_place "sq_sur_drop_0N"), and they are woken from
;  survival_drop_pod_manager under (if g_sur_drop_spawn (wake drop_pod_0N)) with
;  (begin_random_count g_sur_drop_limit ...).
;
;  After the character patch those squads spawn Spartan-bodied actors, so leaving the stock event on
;  would drop Spartan-looking ENEMIES into the arena and would also fight the purchase system for the
;  same four squads.  Setting the two stock globals below turns the event off without deleting or
;  rewriting a single stock script, which keeps the diff against Bungie's text to two lines.
;
;  Both globals are stock: (global boolean g_sur_drop_spawn true) at decompile L206 and
;  (global short g_sur_drop_limit 0) at L207, raised to 1 or 2 at runtime by L5465/L5468.
; =====================================================================================================
(script startup void fe_holdout_stock_hooks
    (set g_sur_drop_spawn false)
    (set g_sur_drop_limit 0)
)
