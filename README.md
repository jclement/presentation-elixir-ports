# From CLI to LiveView 
A presentation demonstrating how to add a web UI to legacy command-line tools using Elixir, Phoenix LiveView, and OTP.

## Overview

This presentation teaches Elixir developers how to:

- Use **Ports** to communicate with external OS processes safely
- Wrap ports in **GenServers** for state management and clean APIs
- Build **single-file Phoenix LiveView** applications (no asset pipeline!)
- Use **Phoenix PubSub** to broadcast real-time updates to multiple browser tabs

## What's Included

- **presentation.md** - Marp-based presentation slides
- **server.exs** - Full single-file Phoenix LiveView demo
- **server-basic.exs** - Minimal Phoenix LiveView example (counter)
- **example-ports-simple.exs** - Basic port communication with GenServer
- **example-ports-lines.exs** - Port with line-by-line processing
- **images/** - Presentation graphics and diagrams

## Running the Examples

### Prerequisites

- Elixir 1.14+ and Erlang/OTP 25+
- An `execute-sync` binary (or replace with your own CLI tool)

### Main Demo

```bash
elixir server.exs
# Visit http://localhost:4000
```

### Basic Phoenix Example

```bash
elixir server-basic.exs
# Visit http://localhost:4001
```

### Port Examples

```bash
elixir example-ports-simple.exs
elixir example-ports-lines.exs
```

## Viewing the Presentation

The presentation is built with [Marp](https://marp.app/). You can:

1. **Use Marp CLI:**
   ```bash
   npm install -g @marp-team/marp-cli
   marp presentation.md --html
   ```

2. **Use VS Code:** Install the [Marp for VS Code](https://marketplace.visualstudio.com/items?itemName=marp-team.marp-vscode) extension

3. **View Online:** GitHub Pages deployment at https://jclement.github.io/presentation-elixir-ports/

## Key Concepts

### Ports
Ports provide a safe way to communicate with external OS processes without risking the Erlang VM. Unlike NIFs, port crashes don't bring down your application.

### GenServer
The idiomatic way to manage stateful processes in Elixir. Perfect for owning ports, accumulating data, and providing clean APIs to the rest of your application.

### Single-File Phoenix
All the power of Phoenix LiveView without the complexity of a full Mix project. Great for demos, learning, and quick prototypes.

### PubSub
Decouples producers from consumers, allowing multiple LiveView processes to receive real-time updates when events occur.

## Author

**Jeff Clement**
- Website: [https://owg.me](https://owg.me)
- GitHub: [@jclement](https://github.com/jclement)

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Acknowledgments

Built with:
- [Elixir](https://elixir-lang.org/)
- [Phoenix Framework](https://www.phoenixframework.org/)
- [Phoenix LiveView](https://hexdocs.pm/phoenix_live_view/)
- [Marp](https://marp.app/)