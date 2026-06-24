{lib, ...}: {
  perSystem = {pkgs, ...}: let
    py = pkgs.python3Packages;
  in {
    packages.kicad-mcp = py.buildPythonApplication rec {
      pname = "kicad-mcp";
      version = "0.1.0-unstable-2026-06-21";
      pyproject = true;

      src = pkgs.fetchFromGitHub {
        owner = "lamaalrajih";
        repo = "kicad-mcp";
        rev = "98c9ea41cb393393a8bafd157a93e84431e00afb";
        hash = "sha256-45+uc0QMqQKCRkmUOq/+F36Ap4Ab3iiJy0kTqDz2SeI=";
      };

      build-system = [py.hatchling];

      dependencies = [
        py.mcp
        py.fastmcp
        py.pandas
        py.pyyaml
        py.defusedxml
      ];

      pythonImportsCheck = ["kicad_mcp"];

      meta = {
        description = "Model Context Protocol server for KiCad EDA files";
        homepage = "https://github.com/lamaalrajih/kicad-mcp";
        license = lib.licenses.mit;
        mainProgram = "kicad-mcp";
        platforms = ["x86_64-linux"];
      };
    };
  };
}
