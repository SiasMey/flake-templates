{
  description = "A collection of flake templates as starting points for your awesome projects";

  outputs = {
    self,
    nixpkgs,
    ...
  } @ inputs: {
    templates = {
      go = {
        path = ./go;
        description = "Template for a go project";
      };
      rust = {
        path = ./rust;
        description = "Template for a rust project";
      };
      python = {
        path = ./python;
        description = "Template for a python project";
      };
    };
  };
}
