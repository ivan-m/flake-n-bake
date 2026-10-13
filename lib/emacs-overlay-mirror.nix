{ lib, pkgs }:

let
  defaultMirrorByDomain = {
    "elpa.gnu.org" = "https://raw.githubusercontent.com/d12frosted/elpa-mirror/refs/heads/master/gnu";
    "elpa.nongnu.org" =
      "https://raw.githubusercontent.com/d12frosted/elpa-mirror/refs/heads/master/nongnu";
  };

  # Wraps nix-community/emacs-overlay and rewrites package source URLs
  # to a mirror when the package's homepage matches a known domain (by
  # default, GNU and Non-GNU ELPA to GitHub mirrors).
  #
  # This is useful when upstream ELPA hosts are slow, blocked, or unreliable.
  # Instead of fetching from the original ELPA endpoint, we inspect each package's
  # homepage and, if it contains a configured domain such as "elpa.gnu.org" or
  # "elpa.nongnu.org", we replace the source URL with a file served from the
  # corresponding mirror.
  #
  # Inputs:
  #   emacsOverlay:
  #     The overlay value returned by nix-community/emacs-overlay. The helper
  #     expects an attribute set with an `overlays.default` attribute.
  #
  #   mirrorByDomain:
  #     An attribute set mapping domains to mirror base URLs, for example:
  #
  #       {
  #         "elpa.gnu.org" = "https://raw.githubusercontent.com/d12frosted/elpa-mirror/refs/heads/master/gnu";
  #         "elpa.nongnu.org" = "https://raw.githubusercontent.com/d12frosted/elpa-mirror/refs/heads/master/nongnu";
  #       }
  #
  # Behavior:
  #   - Only applies to packages that are overrideable and have a `meta.homepage`.
  #   - Finds the longest matching domain in `mirrorByDomain`.
  #   - Reuses the package version and existing `src.outputHash` for integrity.
  #   - Sets `urls = [ ]` to avoid falling back to the original upstream URLs.
  #   - Leaves packages unchanged when no matching homepage domain is found.
  #
  # Example:
  #
  #   let
  #     emacsMirror = import ./lib/emacs-overlay-mirror.nix { inherit lib pkgs; };
  #   in
  #   {
  #     nixpkgs.overlays = [
  #       emacsMirror.mkMirroredEmacsOverlay {
  #         emacsOverlay = inputs.emacs-overlay;
  #       }
  #     ];
  #   }
  #
  # This helper is intentionally conservative: if a package is not overrideable or
  # does not match a configured mirror domain, it is left as-is.
  mkMirroredEmacsOverlay =
    {
      emacsOverlay,
      mirrorByDomain ? defaultMirrorByDomain,
    }:
    emacsOverlay
    // {
      overlays = emacsOverlay.overlays // {
        default =
          final: prev:
          let
            baseSet = emacsOverlay.overlays.default final prev;
          in
          baseSet
          // {
            emacsPackagesFor =
              emacs:
              (baseSet.emacsPackagesFor emacs).overrideScope (
                efinal: eprev:
                builtins.mapAttrs (
                  pkgName: pkg:
                  let
                    isOverridable = builtins.isAttrs pkg && builtins.hasAttr "overrideAttrs" pkg;

                    # Elpa packages have a `homepage` attribute that
                    # points to the package's homepage. We can use
                    # this to determine which mirror to use for the
                    # package. If the package is overridable and has a
                    # homepage, we will check if the homepage matches
                    # any of the domains in `mirrorByDomain`. If it
                    # does, we will override the package's source URL
                    # to point to the mirror.
                    homepage = if isOverridable then pkg.meta.homepage or "" else "";

                    match = builtins.filter (domain: lib.hasInfix domain homepage) (builtins.attrNames mirrorByDomain);

                    mirror =
                      if match == [ ] then
                        null
                      else
                        let
                          ordered = builtins.sort (a: b: builtins.stringLength a > builtins.stringLength b) match;
                        in
                        mirrorByDomain.${builtins.head ordered};
                  in
                  if isOverridable && mirror != null then
                    pkg.overrideAttrs (
                      _: oldAttrs:
                      let
                        srcName = oldAttrs.src.name or "";
                        extension = if lib.hasSuffix ".zst" srcName then "tar.zst" else "tar";
                        version = oldAttrs.version;
                      in
                      {
                        src = pkgs.fetchurl {
                          url = "${mirror}/${pkgName}-${version}.${extension}";
                          sha256 = oldAttrs.src.outputHash;
                        };
                        urls = [ ];
                      }
                    )
                  else
                    pkg
                ) eprev
              );
          };
      };
    };
in
{
  inherit mkMirroredEmacsOverlay;
  defaultMirrorByDomain = defaultMirrorByDomain;
}
