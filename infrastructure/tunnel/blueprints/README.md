# Managing Resources via Blueprints

What's exposed through Pangolin (resources, targets, access rules) is
tracked in git as [Blueprints](https://docs.pangolin.net/manage/blueprints):
**one YAML file per resource** in this directory (`jellyfin.yaml`,
`seerr.yaml`, `pangolin-test.yaml`, ...). This is the source of truth for
resource/rule config - the dashboard's Settings > Blueprints page is only
how it gets applied, never edited directly there for anything tracked here.

One file per resource is deliberate: applying more than one resource's
target in the same paste breaks Newt's live-update path for all but one
of them (see "Why one file per resource" below). Separate files make
"one resource per apply" the default - copy a file, paste it - instead
of something to remember by hand.

## Workflow

1. Edit the relevant file(s) here (or ask Claude to).
2. Review the diff like any other change.
3. For **each changed file**, paste its full contents into the
   dashboard's **Settings > Blueprints** page and apply - one file, one
   apply. Never combine multiple files into a single paste. This step is
   deliberately manual - no scheduled apply, no CI trigger, no API call
   ([#103](https://github.com/MattClarke131/project-seeds/issues/103)
   tracks automating it) - so it can never silently clobber a change
   made through the dashboard.
4. If you get `Resource already exists: <domain> in org <org>`, the
   file's key doesn't match the resource's real niceId (see schema
   gotchas below). The apply is rejected atomically - nothing gets
   touched - fix the key and retry.
5. A single-resource apply doesn't need a Newt restart (confirmed by
   direct testing, including with a genuinely different target value).
   Restart only if you applied more than one file back-to-back without
   verifying in between, or if step 6 shows something's actually broken:
   ```bash
   kubectl rollout restart deployment/newt -n tunnel
   ```
6. Verify by curling the domain directly, not the dashboard's health
   badge (it can show a stale "Unhealthy" status that doesn't reflect
   current reality):
   ```bash
   curl -o /dev/null -w "%{http_code}\n" https://<domain>
   ```

## Why one file per resource

Applying more than one resource's target in the same blueprint paste
breaks Newt's live-update path for all but one of them - confirmed by
direct reproduction: a combined apply immediately 502'd a live resource,
and Newt's logs showed a `Replacing existing target` event with no
matching `Started tcp proxy` line for the second target. A restart fixed
it. This fires even when the applied values are unchanged, not just on
a real diff - so there's no way to know in advance whether a given
multi-resource apply is safe, which is why multi-resource applies are
avoided entirely rather than allowed with a restart-after caveat.

A single-resource apply, including one with a genuinely different
target value, does not trigger this - confirmed directly against
`pangolin-test` with both a hostname-only and a hostname+port change.

## Blueprint schema gotchas

Learned the hard way, verified against `fosrl/pangolin` source
(`server/lib/blueprints/`) rather than assumed from docs:

- **A resource's key in `public-resources:` IS its niceId**, not a
  display name - it's matched directly against the DB. Using the wrong
  key creates a brand-new resource instead of updating the intended one.
  Get the real niceId from the resource's own settings page if it's not
  the plain name you'd expect. (A resource *created* via a blueprint
  apply gets its key as its niceId directly - this only bites resources
  that predate being tracked here.)
- **A target's `site` field is matched against the site's niceId**, not
  its display name. Get this from the dashboard's Sites page.
- **Applying is a full overwrite of each block you specify, not a
  patch.** Omitting `healthcheck` on a target doesn't mean "leave it
  alone" - it disables whatever health check was already configured.
  Decide on purpose whether to include one.
- **`rules[].match` is lowercase** in the Blueprint YAML (`path`,
  `country`, ...) even though the DB/UI use uppercase for the same
  values - easy to transcribe wrong.
- **Rule `action` isn't a network-level allow/block.** `allow` skips all
  further checks including auth entirely; `deny` blocks outright;
  anything unmatched falls through to normal auth (e.g. SSO login) -
  not blocked, just gated behind sign-in.
