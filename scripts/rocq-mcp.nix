# rocq-mcp: an MCP server exposing Rocq/Coq to MCP clients (e.g. Claude Code),
# driving the prover through coq-lsp's Petanque backend (the `pet` binary).
#
# Adapted from the pending nixpkgs packaging:
# https://github.com/NixOS/nixpkgs/pull/542647
# Upstream test suites are skipped here: they need a pet-server on the loopback
# and a miniF2F checkout, neither of which is worth carrying for a dev tool.

{ lib
, python3Packages
, fetchFromGitHub
, makeWrapper
, coqPackages
}:

let
  pytanque = python3Packages.buildPythonPackage (finalAttrs: {
    pname = "pytanque";
    version = "0.2.2";
    pyproject = true;

    src = fetchFromGitHub {
      owner = "LLM4Rocq";
      repo = "pytanque";
      tag = "v${finalAttrs.version}";
      hash = "sha256-1Hae21BuMdE6MjRdiBO7fcsuS4HzahOdLLhynAUox3I=";
    };

    build-system = [ python3Packages.setuptools ];

    dependencies = with python3Packages; [
      requests
      typing-extensions
    ];

    # The suite hardcodes a pet-server on 127.0.0.1:8765.
    doCheck = false;

    pythonImportsCheck = [ "pytanque" ];

    meta = {
      description = "Python client for the Petanque JSON-RPC interface to coq-lsp";
      homepage = "https://github.com/LLM4Rocq/pytanque";
      license = lib.licenses.asl20;
    };
  });
in

python3Packages.buildPythonApplication {
  pname = "rocq-mcp";
  version = "0.3.1-unstable-2026-08-05";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "LLM4Rocq";
    repo = "rocq-mcp";
    rev = "6983113d0844c0b7f987c79dab13988445109bfb";
    hash = "sha256-rFtpCnrudC5U3PlL8WfYk23id7T1v1+xL+xQq+riWXY=";
  };

  build-system = [ python3Packages.setuptools ];

  dependencies = [ pytanque ] ++ (with python3Packages; [
    fastmcp
    psutil
  ]);

  nativeBuildInputs = [ makeWrapper ];

  doCheck = false;

  pythonImportsCheck = [ "rocq_mcp" ];

  # rocq-mcp resolves coqc and pet from PATH at run time, so that it drives
  # whichever switch the caller works in. An MCP client starts the server
  # outside of `nix develop`, so fall back to this project's toolchain when the
  # ambient PATH carries none.
  postFixup = ''
    wrapProgram $out/bin/rocq-mcp \
      --suffix PATH : ${lib.makeBinPath [ coqPackages.coq coqPackages.coq-lsp ]}
  '';

  meta = {
    description = "MCP server for Rocq/Coq proof development";
    homepage = "https://github.com/LLM4Rocq/rocq-mcp";
    license = lib.licenses.asl20;
    mainProgram = "rocq-mcp";
  };
}
