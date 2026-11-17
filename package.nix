{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
  makeWrapper,
  coreutils,
  gnugrep,
  gnused,
  findutils,
}:

let
  version = "0.22.3";
in
stdenvNoCC.mkDerivation {
  pname = "ed-up";
  inherit version;

  # Windows binary release: ED-UP is built with Visual Studio, not buildable here.
  src = fetchurl {
    url = "https://github.com/characterecho-sean/ed-unofficial-patch/releases/download/v${version}/ed-up-core-${version}.zip";
    hash = "sha256-DcwSATpo5GeubMwkLI9sRoByASoefBVQAMWKAUWh7yo=";
  };

  nativeBuildInputs = [
    unzip
    makeWrapper
  ];
  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/ed-up
    unzip -q $src -d $out/share/ed-up
    install -Dm755 ${./ed-up-install.sh} $out/bin/ed-up-install
    substituteInPlace $out/bin/ed-up-install --subst-var-by share $out/share/ed-up
    wrapProgram $out/bin/ed-up-install \
      --prefix PATH : ${
        lib.makeBinPath [
          coreutils
          gnugrep
          gnused
          findutils
        ]
      }
    runHook postInstall
  '';

  meta = {
    description = "ED Unofficial Patch: DLSS, FSR and XeSS for Elite Dangerous: Odyssey";
    homepage = "https://github.com/characterecho-sean/ed-unofficial-patch";
    license = lib.licenses.mit; # the bundled DLLs carry their own licences, see share/ed-up/*LICENSE*
    platforms = [ "x86_64-linux" ];
    mainProgram = "ed-up-install";
  };
}
