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
→ Click **"Save to Playground"**
→ Save as `playground/pricing_model.json`

### 2. Test in Playground

```bash
./test-playground.sh
```

**Watch it:**
- ✅ Validate JSON
- ✅ Copy to backend
- ✅ Compile to machine code
- ✅ Execute with test values
- ✅ Show results!

### 3. Deploy to Production (Optional)

```bash
cd backend-openpricing
cp ../playground/pricing_model.json models/
zig build
./zig-out/bin/openpricing-cli
```

**That's it!** Your pricing model is now compiled into the binary.

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
npm run dev          # Start visual editor

# Playground (Testing)
./test-playground.sh         # Test once
./test-playground.sh --watch # Auto-rebuild on changes

# Backend (Production)
cd backend-openpricing
zig build            # Build everything
zig build run        # Build and run
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

- **Playground Guide**: See `PLAYGROUND_GUIDE.md` - Detailed testing workflow
- **Complete Workflow**: See `WORKFLOW.md`
- **Technical Deep Dive**: See `COMPILE_TIME_APPROACH.md`
- **Project Summary**: See `README.md`

---

**Happy Pricing! 🎯**
