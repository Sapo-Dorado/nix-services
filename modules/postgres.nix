{ pkgs, lib, config, ... }:
let cfg = config.postgres;
in {
  options = {
    postgres = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to include postgres in the development environment.
        '';
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.postgresql_16;
      };

      user = lib.mkOption {
        type = lib.types.str;
        default = "postgres";
        description = ''
          The name of the postgres user.
        '';
      };

      password = lib.mkOption {
        type = lib.types.str;
        default = "postgres";
        description = ''
          The password for the postgres user (For dev only!).
        '';
      };

      dbName = lib.mkOption {
        type = lib.types.str;
        default = "postgres";
        description = ''
          The name of the postgres database
        '';

      };
    };
  };

  config = lib.mkIf cfg.enable {
    moduleBuildInputs = [ cfg.package ];
    setup =
      # bash
      ''
        export PGDATA=$NIX_SHELL_DIR/postgres
      '';

    startService =
      # bash
      ''
        if ! test -d $PGDATA; then
          pg_ctl initdb -D  $PGDATA
          echo "listen_addresses = ${"'"}${"'"}" >> $PGDATA/postgresql.conf
          echo "unix_socket_directories = '$PGDATA'" >> $PGDATA/postgresql.conf
          echo "CREATE USER ${cfg.user} WITH PASSWORD '${cfg.password}' CREATEDB SUPERUSER;" | postgres --single -E ${cfg.dbName}
        fi

        # Don't try to start postgres if it is already running
        if ! test -f $PGDATA/postmaster.pid; then
          pg_ctl                                                  \
            -D $PGDATA                                            \
            -l $PGDATA/postgres.log                               \
            -o "-c unix_socket_directories='$PGDATA'"             \
            -o "-c listen_addresses='*'"                          \
            -o "-c log_destination='stderr'"                      \
            -o "-c logging_collector=on"                          \
            -o "-c log_directory='log'"                           \
            -o "-c log_filename='postgresql-%Y-%m-%d_%H%M%S.log'" \
            -o "-c log_min_messages=info"                         \
            -o "-c log_min_error_statement=info"                  \
            -o "-c log_connections=on"                            \
            start
        fi
      '';

    stopService =
      # bash
      ''
        if test -f $PGDATA/postmaster.pid; then
          pg_ctl -D $PGDATA -U postgres stop
        fi
      '';
  };
}
