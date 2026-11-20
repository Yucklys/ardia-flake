{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  wrapGAppsHook3,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  cairo,
  cups,
  dbus,
  expat,
  glib,
  gtk3,
  gtk4,
  libdrm,
  libGL,
  libgbm,
  libnotify,
  libpulseaudio,
  libsecret,
  libva,
  libx11,
  libxcb,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxkbcommon,
  libxrandr,
  nspr,
  nss,
  pango,
  pipewire,
  systemd,
  vulkan-loader,
  wayland,
  xdg-utils,
}:

let
  sources = lib.importJSON ./sources.json;

  # Libraries Chromium opens with dlopen at runtime rather than linking, so
  # autoPatchelf cannot see them from the ELF headers.
  runtimeLibs = map lib.getLib [
    libGL
    libnotify
    libpulseaudio
    libsecret
    libva
    pipewire
    systemd
    vulkan-loader
    wayland
    gtk3
    gtk4
  ];
in
stdenv.mkDerivation {
  pname = "ardia";
  inherit (sources) version;

  src = fetchurl { inherit (sources) url hash; };
  sourceRoot = "ardia";

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    wrapGAppsHook3
  ];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    cairo
    cups
    dbus
    expat
    glib
    gtk3
    libdrm
    libgbm
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxkbcommon
    libxrandr
    nspr
    nss
    pango
  ];

  runtimeDependencies = runtimeLibs;

  # The Qt shims are only loaded under a Qt desktop and are optional.
  autoPatchelfIgnoreMissingDeps = [
    "libQt5Core.so.5"
    "libQt5Gui.so.5"
    "libQt5Widgets.so.5"
    "libQt6Core.so.6"
    "libQt6Gui.so.6"
    "libQt6Widgets.so.6"
  ];

  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;
  dontWrapGApps = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib $out/share
    cp -a lib/ardia $out/lib/ardia
    cp -a share/applications share/icons $out/share/
    install -Dm644 share/polkit-1/actions/dev.ardia.linux.policy \
      $out/share/polkit-1/actions/dev.ardia.linux.policy

    # The store cannot hold a setuid binary, so Chromium uses its user-namespace
    # sandbox. Without the helper it fails closed when namespaces are denied.
    rm $out/lib/ardia/chrome-sandbox

    # Use nixpkgs' Vulkan loader, which finds the NixOS driver ICDs.
    ln -sf ${lib.getLib vulkan-loader}/lib/libvulkan.so.1 $out/lib/ardia/libvulkan.so.1

    runHook postInstall
  '';

  # ardia-launch only accepts an AppArmor profile naming the exact chrome path,
  # which a store path cannot have ahead of time, so the wrapper starts chrome
  # directly and leaves the sandbox decision to the kernel.
  postFixup = ''
    makeWrapper $out/lib/ardia/chrome $out/bin/ardia \
      "''${gappsWrapperArgs[@]}" \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeLibs} \
      --suffix PATH : ${lib.makeBinPath [ xdg-utils ]} \
      --set CHROME_WRAPPER ardia \
      --add-flags "--disable-features=OutdatedBuildDetector"

    substituteInPlace $out/share/applications/ardia.desktop \
      --replace-fail 'Exec=ardia ' "Exec=$out/bin/ardia "
  '';

  passthru.updateScript = ./update.sh;

  meta = {
    description = "Arc's sidebar and Dia's polish on real Chromium";
    homepage = "https://ardia.dev";
    changelog = "https://github.com/ardia-browser/ardia/releases/tag/v${sources.version}";
    license = lib.licenses.gpl3Only;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "ardia";
  };
}
