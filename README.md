# Neovim Configuration Specification (`neovim-config-spec`)

A lightweight, declarative specification repository designed for AI-assisted pair programming and portable Neovim environment orchestration.

---

## 🎯 Purpose & Intent

Instead of maintaining a complex, machine-specific `~/.config/nvim` repository with hardcoded paths and symlinks across different devices, this repository takes a **spec-first approach**:

1. **Declarative Specification (`LAZY-SPEC.md`)**:
   * Documents all installed plugins, theme suites, custom utilities, and critical keymaps in a structured, portable format.
2. **AI-Driven Machine Provisioning**:
   * Enables an AI coding assistant (such as **Antigravity**, **Claude**, or **ChatGPT**) to read the specification and immediately configure or reconstruct a full LazyVim setup on any target machine with a single instruction.
3. **Advanced Terminal & AI Agent Workflow**:
   * Defines customized enhancements for in-editor terminals, including smart file/URI resolution (`gf`), seamless split navigation, and live theme previewing.

---

## 📂 Repository Contents

* **[`LAZY-SPEC.md`](file:///Users/pkshrestha/git/neovim-config/LAZY-SPEC.md)**: The core declarative specification of all plugins, options, keymaps, and AI agent integration.
* **[`perf-lens/SPEC.md`](file:///Users/pkshrestha/git/neovim-config/perf-lens/SPEC.md)**: Architecture and functional specification for `perf-lens`, the performance profiler, jitter lens, and optimization advisor.
* **[`terminal-enhancement/PLAN.md`](file:///Users/pkshrestha/git/neovim-config/terminal-enhancement/PLAN.md)**: Architecture plan and implementation for multi-direction terminals, dedicated tool runners, and smart link navigation.

---

## 🚀 How to Reconstruct Neovim on a New Machine

On any new workstation with Neovim installed, provide `LAZY-SPEC.md` to your AI assistant with the following prompt:

```text
Please read LAZY-SPEC.md and configure my Neovim setup in ~/.config/nvim according to the specification.
```

The agent will automatically create the required Lua config files and sync all plugins via Lazy.
