factorio-server-nix
-------------------

A factorio server setup in Nix.


Requirements
------------
- A NixOS install with Flakes enabled.


Installation
------------
1. Add the flake to your inputs.

	Example flake.nix:
	------------------
	inputs = {
		inputs.nixpkgs.url = "...";
		inputs.factorio-server = {
			url = "github:emanueljg/factorio-server-nix";
			# man --pager='less -j12 -p inputs.nixpkgs.follows' nix3-flake 
			inputs.nixpkgs.follows = "nixpkgs";
		};
	------------------

2. Import the module and enable the service

	Example basic factorio-server.nix:
	----------------------------
	{ pkgs, factorio-server, ... }: {

	  imports = [ factorio-server.nixosModules.default ];

	  services.factorio-server = {
	    enable = true;

		dataDir = "/var/lib/factorio-server"  # Default.

		socketUser = "YOUR_USERNAME"  # Highly recommended; see 5. Running commands.

	    package = pkgs.factorio-headless  # Default. Probably want to set a newer version though.

	    openFirewall = true;  # opens UDP port 34197
		extraConfig = {  # Merges with ./default-server-settings.json
			# max_players = 10;
		};
		
	  };

	  nixpkgs.config.allowUnfree = true;  # factorio-headless is unfree

	}

3. Done! The factorio server will now start automatically on boot. 

4. Custom map (Optional)

	The map is stored at "${dataDir}/map.zip". It is generated on startup if it does not exist.
	If you want your own custom map, you can either:
	- Customize map generation with factorio-server.mapCreationArgs. 
	  Just remember to remove the old map to generate a new one!
	- Copy over a pregenerated map to the data dir.

5. Running commands (Optional)

	The factorio server runs as a systemd service which listens for stdin through a socket using named pipes.
	In other words, you can write text to a file which then gets sent to the server's chat.
	You can do this manually (echo "hello world" > /tmp/factorio-server.stdin) but this is a bit cumbersome
	to write each time, so a simple shell wrapper is provided:

	$ factorio-cmd hello world
	$ journalctl -u factorio-server | grep 'hello world'
	nov 07 17:31:06 fenix factorio[2219352]: 2023-11-07 17:31:06 [CHAT] <server>: hello world

	If you have no perms for this command, this means the socket is not owned by you. You either need to:
		- Make yourself the socket owner by setting services.factorio-server.socketUser (see 2.)   
		- Run the command as the service user: sudo -u factorio-server factorio-cmd hello world.
		  This can of course be set as a shell alias too. 
