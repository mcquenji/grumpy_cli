# Command routing

`domain/models` contains Command, CommandGroup and the parser-independent
CommandInvocation. `domain/services` defines CommandParserService and
CliRoutingService. Defaults under `infra/services` implement args parsing and core
routing coordination. Parser tree nodes stay private to the default parser.

Override `commandParserServiceBuilder` to change discovery, argument parsing or
help. Override `routingServiceBuilder` to change execution and activation policy.
The app consumes the abstract CLI contract; it never casts to a default router.
Invocations carry explicit non-interactive policy so replacement parsers do not
need the default parser's private nodes or built-in flag handle identities.

## Declaration and execution

Commands map to core leaf routes; groups map to core module routes. Public names
are literal command tokens, not URI patterns. The command tree validates the
entire declaration graph and combines inherited arguments before any config or
DI access. Group-only invocations display help. Unknown commands are usage errors.

`CliApp.run` performs these phases:

1. Validate declarations, parse original argv, and return early for help.
2. Load and validate persisted configuration.
3. Bootstrap the root and activate the selected dependency graph.
4. Run route middleware and execute the handler once.
5. Await cleanup and return the exit status.

The router's `run` is also available for an already bootstrapped application.
Each call executes independently; overlapping calls are rejected. It propagates
errors rather than doing process-level mapping or shutting down the app.

## Core integration

`navigate('/group/command')` activates dependencies and selects a handler, emitting
navigation events without calling `execute`. Query strings and fragments are not
argument transport; use `run(argv)` for invocation input. Dependency readiness
waits for activation only, avoiding a command waiting on its own completion.
Middleware receives core route identity, while typed command arguments remain in
`CommandContext`. The app's existing routing builder remains the customization
point; replacements must preserve the CLI routing contract.
