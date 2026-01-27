[
  inputs: ["{config,lib,test}/**/*.{ex,exs}"],
  excludes: [
    "config/config.exs"
  ],
  line_length: 140,
  import_deps: [:ecto, :ecto_sql],
  locals_without_parens: [],
  export: [
    locals_without_parens: []
  ]
]
