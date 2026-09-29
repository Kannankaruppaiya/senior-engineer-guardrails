# Frontend: AI habits vs senior practice

Applies to React components and Next.js App Router pages. Most points also hold
for other React meta-frameworks.

## Contents
1. Reuse before create
2. Server vs client components (Next.js App Router)
3. Effects and state
4. Data fetching and the four states
5. Forms
6. Styling and design systems
7. Accessibility
8. Responsive layout
9. Performance
10. TypeScript

---

## 1. Reuse before create

Agents regenerate a Button, date formatter or field wrapper in every feature
folder; fixes then land in one copy and the UI drifts. Before writing a component
or helper, search the project's `components/ui`, form primitives, `lib/` and
design system by purpose, and extend what exists.

## 2. Server vs client components (Next.js App Router)

```tsx
// AI: the whole page becomes a client component to silence one error
'use client';
export default function ProductPage({ params }: { params: { id: string } }) { … }
```

```tsx
// Senior: the page stays a Server Component; only the interactive leaf is client
export default async function ProductPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;          // Next.js 15+: params, searchParams, cookies(), headers() are async
  const product = await getProduct(id);
  return <AddToCartButton productId={product.id} />;   // this file has 'use client'
}
```

- `'use client'` goes on the smallest component that needs state, effects or
  browser APIs — not on layouts or pages.
- Keep server-only modules out of client bundles (`import 'server-only'`); don't
  work around the resulting build error.
- Use the idioms of the installed version. Agents mix in Pages Router APIs
  (`getServerSideProps`, `pages/api`) or APIs from a newer major. Check
  `package.json` and the installed docs rather than memory. Next.js publishes a
  codemod that writes version-matched docs for agents into `AGENTS.md` (see the
  "AI agents" guide on nextjs.org).
- Don't call `Date.now()`, `Math.random()` or read `localStorage` during render
  of server-rendered components — that causes hydration mismatches.

## 3. Effects and state

The most frequent AI edit in frontend reviews is an unnecessary `useEffect`.

```tsx
// AI: derived state synced in an effect → extra render, stale values
const [total, setTotal] = useState(0);
useEffect(() => { setTotal(items.reduce((s, i) => s + i.price, 0)); }, [items]);
```

```tsx
// Senior: derive during render
const total = items.reduce((s, i) => s + i.price, 0);
```

- If it can be computed from props or state, compute it.
- To reset state when an entity changes, change the component's `key`.
- `useCallback`/`useMemo` only with a reason. `useCallback(fn, [])` that reads
  props freezes stale values.
- Never disable `react-hooks/exhaustive-deps` or `rules-of-hooks` to get a green
  lint; fix the dependency or explain why and ask.

## 4. Data fetching and the four states

```tsx
// AI
useEffect(() => { fetch('/api/orders').then(r => r.json()).then(setOrders); }, []);
return orders.length ? <List …/> : <p>No orders yet</p>;      // a 500 shows "No orders yet"
```

```tsx
// Senior (when client-side fetching is unavoidable)
type Load<T> = { status: 'loading' } | { status: 'error' } | { status: 'ok'; data: T };
const [state, setState] = useState<Load<Order[]>>({ status: 'loading' });

useEffect(() => {
  const ctrl = new AbortController();
  fetch('/api/orders', { signal: ctrl.signal })
    .then((r) => { if (!r.ok) throw new Error(String(r.status)); return r.json(); })
    .then((data) => setState({ status: 'ok', data }))
    .catch(() => { if (!ctrl.signal.aborted) setState({ status: 'error' }); });
  return () => ctrl.abort();
}, []);

if (state.status === 'loading') return <Spinner />;
if (state.status === 'error') return <ErrorMessage onRetry={…} />;
if (state.data.length === 0) return <EmptyState />;
return <OrderList orders={state.data} />;
```

- Prefer fetching in Server Components or a data library (TanStack Query, SWR)
  that already handles races, caching and errors.
- Always distinguish **loading, error, empty, data**. An error must never render
  as the empty state.
- Check `response.ok`; `fetch().then(r => r.json())` treats a 500 as data.
- Show errors inline near what failed; a toast alone is not enough for a failed save.
- Optimistic updates need a rollback path.

## 5. Forms

| AI habit | Consequence | Senior practice |
|---|---|---|
| `Number(v)` / `z.coerce.number()` on optional numeric inputs | `""` becomes `0` and passes "required" | Map `""` to `null` explicitly; schema `z.number().nullable()`; required fields reject `null` |
| `valueAsNumber` without a NaN check | `NaN` reaches the API | Treat `NaN` as empty/invalid |
| Inputs cleared after a failed submit (React 19 form actions reset uncontrolled inputs) | User retypes everything | Keep values in state, or return submitted values with the error and re-populate |
| Validation only in the browser | API accepts anything | Same schema on the server |
| Submit stays enabled while saving | Double click → duplicate records | Disable while pending; idempotency key or unique constraint server-side |
| `onClick={() => save()}` without handling | Failure is silent | `await`, show the error, map server field errors back to fields |
| `redirect()` inside `try/catch` (Next.js) | Redirect is thrown and swallowed | Call `redirect()` after the try/catch |
| Placeholder as the only label | Inaccessible; label vanishes on typing | Visible `<label>` bound to the input |
| Deprecated APIs (`useFormState`) | Warnings, future breakage | `useActionState` (React 19) |

After failed validation, move focus to the first invalid field and link each
error to its input with `aria-describedby`.

## 6. Styling and design systems

On prompts that said nothing about styling, agents made 42–117 design-system
violations per 8-task run; one round of design-system lint feedback took every
model tested to zero.

- Use theme tokens and component variants, not raw hex colours or arbitrary
  values (`text-[13px]`, `mt-[7px]`) — they bypass tokens and break dark mode.
- Don't restyle shared primitives from outside with long `className` overrides;
  add a variant.
- Use `cn()`/`clsx` for conditional classes; keep class strings static enough for
  Tailwind to detect.
- If the project uses shadcn/ui, run its linter (`@shadcn/lint`) in the loop.

## 7. Accessibility

Checkers such as axe pass AI UIs on contrast and alt text but miss semantics:
generic labels ("Submit", "Click here", "Field 1") were the most common violations.

- Buttons and links say what they do.
- Every input has a visible, associated label; errors are announced and linked.
- Dialogs and drawers: accessible name, focus moves in and is trapped, Escape
  closes, focus returns. Use a tested primitive (Radix, React Aria, the design
  system's Dialog) — don't hand-roll a `div` modal.
- Everything works with the keyboard alone.

## 8. Responsive layout

68% of AI-generated pages broke in at least one browser/device environment
(vs 40% of human pages), almost all on smaller devices: missing viewport meta
(46%) and flex rows that don't wrap (29.5%).

- Make sure the viewport meta is present (Next.js adds it by default; don't
  remove it).
- Use `flex-wrap`, responsive grid columns and `min-w-0` on flex children with
  long text; check at 360 px width.

## 9. Performance

- Import only what you use; avoid barrel files that pull whole folders into the
  client bundle and heavy libraries for small tasks.
- Keep client components small so the server does the heavy lifting.
- Don't add `React.memo`/`useMemo` by default; it does nothing when parents pass
  new inline functions each render, and the React Compiler (if enabled) handles
  most of it.

## 10. TypeScript

Agent PRs add `any` about 9× more often than human PRs and use more non-null and
type assertions.

- Use `unknown` + schema parsing at boundaries, `z.infer<typeof Schema>` for
  types, narrowing and discriminated unions inside.
- No `as SomeType`, `!` or `@ts-ignore` to silence errors; enable `strict` and
  `noUncheckedIndexedAccess`.
- Import shared types rather than redefining near-copies; don't guess field
  names — open the type.
