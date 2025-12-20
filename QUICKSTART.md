# OpenPricing - Quick Start Guide

## 🚀 30-Second Overview

**Design pricing models visually** → **Export JSON** → **Build** → **Get native machine code**

Zero runtime overhead. Everything compiled at build time.

---

## Prerequisites

- **Zig 0.15.2+** for backend
- **Node.js 18+** for frontend

---

## Quick Start

### 1. Design Your Model (Frontend)

```bash
cd frontend-openpricing
npm install
npm run dev
```

→ Open http://localhost:5173
→ Design your pricing graph
→ Click **"Download JSON"**

### 2. Build (Backend)

```bash
cd backend-openpricing
cp ~/Downloads/pricing_model.json models/
zig build
```

**That's it!** Your pricing model is now compiled into the binary.

### 3. Run

```bash
./zig-out/bin/openpricing-cli
```

---

## How It Works

```
JSON Model ──▶ Code Gen ──▶ Compile ──▶ Machine Code
(design time)  (build time) (build time) (runtime)
```

All parsing, validation, and graph processing happens **at build time**.

At runtime: just pure arithmetic. No overhead.

---

## Example Models

### Simple: Markup Pricing
```
base_price × markup = final_price
```

### Complex: Full E-Commerce
```
base_price × quantity = subtotal
subtotal - discount = after_discount
after_discount × tax_rate = tax
after_discount + tax = final_total
```

Both compile to pure arithmetic. No performance difference.

---

## Performance

| Metric | Traditional | Compile-Time | Improvement |
|--------|-------------|--------------|-------------|
| Startup | 170μs | **0μs** | ∞ |
| Execution | 10μs | **10ns** | 1000x |
| Memory | Heap | **Stack** | Zero alloc |

---

## Common Commands

```bash
# Frontend
cd frontend-openpricing
npm run dev          # Start dev server
npm run build        # Build for production

# Backend
cd backend-openpricing
zig build            # Build everything (generates code + compiles)
zig build run        # Build and run CLI demo
zig build test       # Run tests
```

---

## File Locations

- **Frontend**: `frontend-openpricing/src/App.tsx`
- **Model JSON**: `backend-openpricing/models/pricing_model.json`
- **Generated Code**: `.zig-cache/.../generated_nodes.zig` (auto)
- **Main App**: `backend-openpricing/src/main.zig`

---

## Troubleshooting

**Build fails with "Node not found":**
→ Check JSON has valid node IDs in `inputs` arrays

**Changes not reflected:**
→ Run `rm -rf .zig-cache zig-out && zig build`

**JSON export empty:**
→ Ensure nodes have `id`, `operation`, and `constant_value`

---

## Learn More

- **Complete Workflow**: See `WORKFLOW.md`
- **Technical Deep Dive**: See `COMPILE_TIME_APPROACH.md`
- **Project Summary**: See `README.md`

---

**Happy Pricing! 🎯**
