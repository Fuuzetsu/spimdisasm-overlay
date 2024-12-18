# Generated by pip2nix 0.8.0.dev1
# See https://github.com/nix-community/pip2nix

{ pkgs, fetchurl, fetchgit, fetchhg }:

self: super: {
  "rabbitizer" = super.buildPythonPackage rec {
    pname = "rabbitizer";
    version = "1.12.5";
    src = fetchurl {
      url = "https://files.pythonhosted.org/packages/24/ab/fccfaa073aa672129ea625ba2622a065ba505fd53c8c08a664154b47b54e/rabbitizer-1.12.5.tar.gz";
      sha256 = "11k9hp5zzn3l65cjsv4pcq8anqlanpwfglg3jddasipjbphc5kv8";
    };
    format = "setuptools";
    doCheck = false;
    buildInputs = [];
    checkInputs = [];
    nativeBuildInputs = [];
    propagatedBuildInputs = [];
  };
  "spimdisasm" = super.buildPythonPackage rec {
    pname = "spimdisasm";
    version = "1.31.2";
    src = fetchurl {
      url = "https://files.pythonhosted.org/packages/73/9b/6c0b1c614d1621c85d4c4b8664ef3eda6893ed5b34e4ec0820506fea1be1/spimdisasm-1.31.2-py3-none-any.whl";
      sha256 = "06fsvljyf6wy0xinwk2jz55krj90wdrpw2sd9dcr2qxnx7gmfqpm";
    };
    format = "wheel";
    doCheck = false;
    buildInputs = [];
    checkInputs = [];
    nativeBuildInputs = [];
    propagatedBuildInputs = [
      self."rabbitizer"
    ];
  };
}
