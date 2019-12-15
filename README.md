# ubernix

[home modules][home-manager] on [asteroids][uberspace]

## Installation

If you haven't got working installations of [Nix] and [home-manager], consult
the [tutorial in the uberlab][uberlab] (TODO: create guide).


To use the tools, just copy them into your PATH.

To use ubernix with your working home-manager configuration, proceed as follows:

1.  Add the ubernix channel:

    ```console
    $ nix-channel --add https://github.com/jorsn/ubernix/archive/master.tar.gz ubernix
    $ nix-channel --update
    ```

2.  You may have to add

    ```shell
    export NIX_PATH=$HOME/.nix-defexpr/channels${NIX_PATH:+:}$NIX_PATH
    ```

    to your shell (see [nix#2033](https://github.com/NixOS/nix/issues/2033)).

3.  Import ubernix in your `home.nix`:

    ```nix
    imports = [ <ubernix> ];
    ```

Then, the ubernix options and packages are available in your `home.nix`.

## Documentation

The main documentation is the [uberlab guide][uberlab].


[home-manager]: https://github.com/rycee/home-manager/
[Nix]:          https://nixos.org/nix/
[uberlab]:      https://lab.uberspace.de/guide_nix.html
[uberspace]:    https://uberspace.de
