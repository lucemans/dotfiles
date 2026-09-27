---
name: web-design
description: Web frontend design conventions. Use when designing, reviewing, or changing visual UI, layouts, styling, or frontend components.
---

# Web Design

First apply repository-local design rules and the framework skill. Keep the existing design system, tokens, and component patterns.

- Make a clear visual hierarchy with type scale, contrast, spacing, and alignment.
- Use simple page structures. Do not put cards inside cards.
- Use one primary action per view. Make secondary actions quieter.
- Group related content with spacing and headings. Add borders, shadows, or backgrounds only after you group the content.
- If Tailwind is configured, use parent layout spacing such as `space-y-4`, `gap-4`, and `gap-y-4`. Do not use sibling-specific margins such as `mt-4`.
- Do not use pills and badges unless the user asks for them.
- Use the project token scale for spacing, radii, colors, and type styles.
- Design responsive layouts with purpose. Start with the narrow viewport. Do not let content overflow horizontally. Keep touch targets and reading order.
- Use semantic HTML, visible keyboard focus, accessible names, and sufficient contrast. Use real buttons and real links.
- Give the same design attention to loading, empty, error, disabled, hover, and focus states as to the default state.
- Do not use ornamental gradients, shadows, or generic dashboard visual noise. Use them only if the product already uses them.
