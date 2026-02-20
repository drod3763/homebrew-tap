# Drod3763 Tap

## How do I install formulae and casks?

`brew install drod3763/tap/<formula>`

Or `brew tap drod3763/tap` and then `brew install <formula>`.

For casks:

`brew install --cask drod3763/tap/<cask>`

Or, in a `brew bundle` `Brewfile`:

```ruby
tap "drod3763/tap"
brew "<formula>"
```

## Documentation

`brew help`, `man brew` or check [Homebrew's documentation](https://docs.brew.sh).

## Updating `rar`

- Local update: `scripts/update-rar.sh 7.20`
- GitHub Actions update: run the `update-rar` workflow with a version input (for example `7.20`)
