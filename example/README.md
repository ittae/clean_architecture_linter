# clean_architecture_linter example

A minimal, runnable Dart project showing how to enable `clean_architecture_linter`
and what its warnings look like in practice.

```
example/
├── analysis_options.yaml        # enables the plugin (path dependency on ..)
└── lib/
    ├── good_examples/            # 0 warnings — Domain/Data pass-through Todo feature
    └── bad_examples/             # intentionally violates 2 rules, on purpose
```

## Run it

```bash
cd example
dart pub get
dart analyze
```

`good_examples/` reports nothing. `bad_examples/` reports exactly two warnings:

```
warning - lib/bad_examples/features/todo/data/models/todo_remote_model.dart:12:1 - Model name "TodoRemoteModel" should not include DataSource implementation "remote". ... - model_naming_convention
warning - lib/bad_examples/features/todo/data/repositories/todo_repository_impl.dart:25:3 - Repository should NOT use Result pattern. Use pass-through pattern instead. ... - repository_pass_through
```

Each file in `bad_examples/` has a comment pointing at its fixed counterpart in
`good_examples/`. Applying that fix (e.g. renaming `TodoRemoteModel` ->
`TodoModel`) removes the warning.

## How the plugin is wired here

`analysis_options.yaml` in this folder points the plugin at the package root
via a path dependency, since this example lives inside the package's own repo:

```yaml
plugins:
  clean_architecture_linter:
    path: ..
```

In your own project, use a version constraint instead — see the root
[README](../README.md#-quick-start) / [README_KO](../README_KO.md#-빠른-시작).

For the full rule catalog and more good/bad snippets, see
[doc/EXAMPLES.md](../doc/EXAMPLES.md).
