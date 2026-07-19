---
name: web-design
description: Web frontend design conventions. Use when designing, reviewing, or changing visual UI, layouts, styling, or frontend components.
---

# Web Design

Apply repository-local design rules and the framework skill first. Preserve the existing design system, tokens, and component patterns.

- Establish a clear visual hierarchy with purposeful type scale, contrast, spacing, and alignment.
- Prefer simple page structure over decorative containers. Do not put cards inside cards.
- Use one primary action per view; make secondary actions visually quieter.
- Group related content with spacing and headings before adding borders, shadows, or backgrounds.
- When Tailwind is configured, prefer parent layout spacing such as `space-y-4`, `gap-4`, and `gap-y-4` over sibling-specific margins such as `mt-4`.
- Avoid pills and badges unless explicitly tasked.
- Keep spacing, radii, colors, and type styles on the project's existing token scale.
- Design responsive layouts intentionally: start with the narrow viewport, avoid horizontal overflow, and preserve touch targets and reading order.
- Use semantic HTML, visible keyboard focus, accessible names, sufficient contrast, and real buttons and links.
- Give loading, empty, error, disabled, and hover/focus states the same design attention as the default state.
- Avoid ornamental gradients, shadows, and generic dashboard visual noise unless they are established by the product.
