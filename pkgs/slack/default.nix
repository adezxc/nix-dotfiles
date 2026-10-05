{
  # Slack with its notification and call sounds replaced by classic Skype
  # sounds.
  #
  # The webapp plays these sounds by fetching them from the slack-edge.com
  # CDN, so patching the local files alone is not enough:
  #
  #   1. the sound files inside app.asar (dist/) are replaced with the
  #      Skype sounds (they are served to the webapp through Slack's own
  #      app:// protocol),
  #   2. a small hook is prepended to dist/boot.bundle.cjs that redirects
  #      the webapp's CDN requests for those sounds to the local copies,
  #   3. the loose copies in resources/ are replaced as well.
  #
  # app.asar is extracted and repacked for this (the `asar` tool is already
  # part of the stock slack derivation's nativeBuildInputs). Note that
  # `asar pack` must be run from inside the directory being packed - its
  # glob matching is sensitive to the source path format.
  #
  # The Skype sounds come from the classic Skype 3.8 sound set
  # (https://archive.org/details/skype-sound-effects-emoticons-.v-3.8.0.188-2008-07-11,
  # converted to mp3); the new-message sound is from
  # https://github.com/RemoraTeam/skype-discord-sounds (Message.mp3).
  lib,
  slack,
}: let
  # Slack sound file name (in app.asar dist/ and resources/) -> Skype sound.
  sounds = {
    # New message ("Knock Brush", Slack's default notification sound).
    knock_brush = ./sounds/new_message.mp3;
    # Incoming call ring.
    calls_incoming_ring_v2 = ./sounds/call_in.mp3;
    # Ringback while waiting for someone to pick up.
    calls_outgoing_ring_v2 = ./sounds/call_out.mp3;
    # You joined a call/huddle.
    calls_you_joined_call_v2 = ./sounds/call_init.mp3;
    # Someone else joined the call.
    calls_they_joined_call_v2 = ./sounds/user_added.mp3;
    # You left the call.
    calls_you_left_call_v2 = ./sounds/hangup.mp3;
    # Someone else left the call.
    calls_they_left_call_v2 = ./sounds/user_left.mp3;
  };
  copySounds = dir:
    lib.concatStringsSep "\n" (lib.mapAttrsToList (name: path: "cp ${path} ${dir}/${name}.mp3") sounds);
in
  slack.overrideAttrs (old: {
    postInstall =
      (old.postInstall or "")
      + ''
        resourceDir=$out/lib/slack/resources
        extractDir=$(mktemp -d)

        # Unpack the archive (also pulls in files from app.asar.unpacked).
        asar extract $resourceDir/app.asar $extractDir

        # 1) Replace the sounds served through the app:// protocol.
        ${copySounds "$extractDir/dist"}

        # 2) Prepend the CDN-redirect hook to the boot bundle.
        cat ${./skype-sound-inject.js} $extractDir/dist/boot.bundle.cjs > $extractDir/boot.bundle.cjs.tmp
        mv $extractDir/boot.bundle.cjs.tmp $extractDir/dist/boot.bundle.cjs

        # Repack. The globs keep native modules, the utility-process entry
        # bundles and dist/resources as real files in app.asar.unpacked,
        # mirroring the upstream layout (a superset is fine, a subset is not:
        # plain node processes cannot load from inside an asar archive).
        rm $resourceDir/app.asar
        rm -rf $resourceDir/app.asar.unpacked
        (cd $extractDir && asar pack . $resourceDir/app.asar \
          --unpack "{**/*.node,dist/*.bundle.js}" \
          --unpack-dir "{node_modules,dist/resources}")
        rm -rf $extractDir

        # 3) Replace the loose copies next to app.asar too.
        ${copySounds "$resourceDir"}
      '';

    passthru = (old.passthru or {}) // {skypeNotificationSound = true;};
  })
