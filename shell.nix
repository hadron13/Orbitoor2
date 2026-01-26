let
  nixpkgs = fetchTarball "https://github.com/NixOS/nixpkgs/tarball/nixos-unstable";


  pkgs = import nixpkgs { config = {}; overlays = [
    (final: prev: {
        ols = prev.ols.overrideAttrs (oldAttrs: {
           nativeBuildInputs = oldAttrs.nativeBuildInputs ++ [ pkgs.git ];
            installPhase = oldAttrs.installPhase + ''
              cp -r builtin $out/bin/
            '';
          });
        })
    ]; };

in

pkgs.mkShell.override { stdenv = pkgs.clangStdenv; }
{  
  packages = with pkgs; [
    libGL
    sdl3 
    odin
    ols
    libcxx
  ];  
  shellHook = ''
        export LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath [
          pkgs.SDL2
        ]}
  '';

}
