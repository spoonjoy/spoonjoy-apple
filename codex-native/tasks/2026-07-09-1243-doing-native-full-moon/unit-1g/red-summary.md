# Unit 1g Red Summary

Command:

```sh
ruby scripts/check-launch-screenshot-contract.rb
```

Log:

- `check-launch-screenshot-contract-red.log`

Expected red failures:

- `scripts/capture-native-screenshot-matrix.sh` lacks a `cookbook-detail|cookbook-detail|...` route entry.
- `scripts/capture-native-screenshots.sh` rejects `--route cookbook-detail`.
- `scripts/validate-design-review.rb` does not accept `cookbook-detail` manifests.
- The screenshot success lane cannot prove `AppRoute.cookbookDetail` state (`cookbook:cookbook_weeknights`), durable cache seed (`cookbook-detail:cookbook_weeknights`), or `CookbookDetailView` accessibility proof.
