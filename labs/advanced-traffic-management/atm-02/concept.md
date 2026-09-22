# Concept: Header-Based Routing with the Gateway API

`HTTPRoute` rules can match on more than just path and hostname.
`spec.rules[].matches[].headers` lets a single rule require that one or
more request headers be present with a specific value (`type: Exact`, the
default) or match a regular expression (`type: RegularExpression`). This is
the mechanism behind common patterns like canary opt-in headers, internal
"beta" flags, or A/B testing cookies rewritten to a header upstream —
routing decisions are made purely on request metadata, with no DNS or extra
hostname required.

Precedence matters here: the Gateway API spec defines a strict ordering for
which rule wins when more than one rule's `matches` could apply to the same
request. Roughly, from highest to lowest priority: exact path match, then
longest path-prefix match, then (at equal path specificity) the rule with
the **largest number of header matches**, then method match, then query
param matches, and finally list order as a tiebreaker. In practice this
means a rule with a header requirement placed anywhere in `spec.rules`
correctly takes priority over a header-less catch-all rule at the same
path — you do not need to fight over ordering to get a canary-by-header
rule to "win" only for requests that actually carry the header.
