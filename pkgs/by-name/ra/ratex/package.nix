{
  lib,
  fetchFromGitHub,
  rustPlatform,
  nix-update-script,
}:

rustPlatform.buildRustPackage rec {
  pname = "ratex";
  version = "0.1.16";

  src = fetchFromGitHub {
    owner = "erweixin";
    repo = "RaTeX";
    tag = "v${version}";
    hash = "sha256-iSN29xs40YwRKqIYzhW4VGHbp43Izri0L4qMxPjhtQk=";
  };

  cargoHash = "sha256-Od8mvBK7eeaar23xz5rdBkZEpYVNyJlLlAns1TuLhKM=";

  # only the three command-line crates are built: a plain workspace build would
  # also pull in the gtk4, cairo, wasm and ffi members, which need GUI
  # libraries and are not shipped
  # the three CLIs do not enable the same feature set, and `cargo build` has no
  # per-package feature syntax, so each crate gets its own invocation
  # `embed-fonts` is mandatory: without it the binaries look for a KaTeX font
  # tree on disk and produce fontless output
  buildPhase = ''
    runHook preBuild

    cargo build --release --offline -p ratex-render --features embed-fonts
    cargo build --release --offline -p ratex-svg --features cli,embed-fonts
    cargo build --release --offline -p ratex-pdf --features cli,embed-fonts

    runHook postBuild
  '';

  # the build phase bypasses `cargoBuildHook`, so the install is written out
  # directly instead of relying on the hook's release-tmp staging
  dontCargoInstall = true;

  # the default hook tests the whole workspace, which pulls in the gtk4 and
  # wasm members; test only the shipped crates, with the same feature sets
  # as `buildPhase`
  doCheck = true;

  checkPhase = ''
    runHook preCheck

    cargo test --release --offline -p ratex-render --features embed-fonts
    cargo test --release --offline -p ratex-svg --features cli,embed-fonts
    cargo test --release --offline -p ratex-pdf --features cli,embed-fonts

    runHook postCheck
  '';

  # upstream binary names are `render`, `render-svg` and `render-pdf`; the
  # first is too generic for a shared bin directory, so all three are prefixed
  installPhase = ''
    runHook preInstall

    install -Dm755 target/release/render $out/bin/ratex-render
    install -Dm755 target/release/render-svg $out/bin/ratex-svg
    install -Dm755 target/release/render-pdf $out/bin/ratex-pdf

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "KaTeX-compatible LaTeX math typesetting engine";
    homepage = "https://github.com/erweixin/RaTeX";
    # the bundled KaTeX fonts, under fonts/, are SIL OFL 1.1
    license = with lib.licenses; [
      mit
      ofl
    ];
    maintainers = with lib.maintainers; [ niozow ];
    mainProgram = "ratex-render";
    platforms = lib.platforms.unix;
  };
}
