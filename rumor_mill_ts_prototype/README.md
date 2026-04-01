# Rumor Mill — TypeScript/Canvas Prototype (ARCHIVED)

> **Status: ARCHIVED — superseded by the Godot 4.x implementation in `../rumor_mill/`**

## Why this prototype exists

Early exploration of Rumor Mill used a TypeScript + HTML5 Canvas stack to rapidly
validate core mechanics (grid rendering, basic NPC positioning) without committing to
a full engine.

## Engine decision (SPA-7)

After evaluation, **Godot 4.x was selected** over the TypeScript/Canvas approach for
the following reasons:

| Factor | TypeScript/Canvas | Godot 4.x |
|---|---|---|
| Isometric TileMap | Manual implementation required | Built-in, battle-tested |
| NPC pathfinding | Custom A* needed | NavigationAgent2D built-in |
| Day/night & shaders | Canvas 2D limited | CanvasModulate + shader support |
| Scene tooling | None (code-only) | Full editor, scene tree, debugger |
| Steam deployment | Complex bundling | One-click export templates |
| Animation | Manual spritesheet code | AnimationPlayer, AnimatedSprite2D |

The TypeScript prototype is preserved here for reference in case any logic needs to be
ported back, but **no further development will happen on this branch.**

## Active project

See `../rumor_mill/` for the Sprint 1 Godot 4.x implementation covering:
- 48×48 isometric TileMap
- Manor, Tavern, Chapel, Market placeholder buildings
- Camera pan/zoom
- NPC entity system with random-walk tick loop
- Day/night cycle with visual CanvasModulate

## Reference issues

- Engine decision: [SPA-7](/SPA/issues/SPA-7)
- Vertical slice scope: [SPA-8](/SPA/issues/SPA-8)
- Sprint 1 implementation: [SPA-10](/SPA/issues/SPA-10)
