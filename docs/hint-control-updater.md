# hint-control updater: what it guards and what it leaves alone

`scripts/update-hint-control.sh` and `.github/workflows/update-hint-control.yml` keep
`Casks/hint-control.rb` pinned to the zips upstream actually published. This note covers
the cases they deliberately do **not** handle, so reviewers don't have to rediscover the
reasoning.

## What the updater does guarantee

- Each zip matches the SHA256 digest GitHub publishes for that release asset. A missing
  digest or asset fails the run.
- Each zip has `HINT Control.app` at its root, where the cask's `app` stanza expects it.
- The cask never moves to an older version unless someone opts in (`allow_downgrade`).
- A version that is already pinned is never given new checksums. If upstream replaced a
  zip under the same tag, the run fails and the cask has to be edited by hand.
- Just before publishing, the workflow repeats those checks against the current `main`
  (a re-run of a failed run reuses its old checkout) and against any open
  `update-hint-control-<version>` branch. A matching open branch is left untouched.
- Runs go one at a time, only from `main`, and the PR always targets `main`.

## Out of scope

### Merging a stale update PR

If PR A (1.17.4) is still open after PR B (1.17.5) merges, merging A would lower the
version. Nothing in this workflow can stop that, because the merge happens after the
workflow has finished. GitHub already blocks the usual path: A and B edit the same lines,
so A conflicts once B lands. Getting the older version in means resolving that conflict
in favour of it on purpose.

A real fix is a required check on `main` that fails any PR lowering a cask or formula
version. It would cover the whole tap, so it belongs in its own change, not in this
updater.

### Checking the app inside the zip

The updater does not check that the `aarch64` zip contains ARM code or the `amd64` zip
Intel code, and it does not launch the app. Those checks test upstream's build, not the
tap's pin. They would need macOS runners and a ~100 MB extract per architecture on every
run, and homebrew-cask's own autobump doesn't do them either. A broken or mislabelled
release is an upstream bug, fixed by the next release. The app also updates itself
through Sparkle, so a bad release reaches existing users whatever the cask pins.

### Races measured in seconds

There are two gaps inside a single PR job, between the guard steps and
`create-pull-request`:

- A maintainer pushes to the update branch during that window. The push can be
  overwritten.
- A newer version merges into `main` during that window. The recheck has already passed.

Only the maintainer can push to that branch or merge into `main`, so both mean racing
your own bot within a few seconds, and both show up in the PR timeline. Closing them
would mean replacing `peter-evans/create-pull-request` (used by every updater in this
tap) with a hand-written push and PR flow pinned to exact SHAs. That isn't worth it.

### Changed checksums while two runs overlap

This case is now covered: runs are serialized (`concurrency`), and an open update branch
with different checksums fails the run. It is listed here because the earlier reasoning
still holds. An open PR is a proposal you review before merging, and if upstream really
replaced a zip, only the new checksums would install.
