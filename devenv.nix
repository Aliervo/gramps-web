{ pkgs, ... }:

{
  # Generate a devcontainer for Codespaces/VS Code
  devcontainer = {
    enable = true;
    # These are needed for podman based systems
    settings = {
      runArgs = [ "--userns=keep-id" ];
      containerUser = "vscode";
      updateRemoteUserUID = true;
      containerEnv.HOME = "/home/vscode";
    };
  };

  # https://devenv.sh/basics/
  env = {
    LANGUAGE = "en";
    OMP_NUM_THREADS = 1;
    GRAMPSWEB_USER_DB_URI = "sqlite:///users.sqlite";
    GRAMPSWEB_MEDIA_BASE_DIR = "./api/data/media";
    GRAMPSWEB_SEARCH_INDEX_DB_URI = "sqlite:///api/data/indexdir/search_index.db";
    GRAMPSWEB_STATIC_PATH = "./api/data/static";
    GRAMPSWEB_PERSISTENT_CACHE_CONFIG__CACHE_DIR = "./api/data/persistent_cache";
    GRAMPSWEB_REQUEST_CACHE_CONFIG__CACHE_DIR = "./api/data/request_cache";
    GRAMPSWEB_THUMBNAIL_CACHE_CONFIG__CACHE_DIR = "./api/data/thumbnail_cache";
    GRAMPSWEB_REPORT_DIR = "./api/data/reports_cache";
    GRAMPSWEB_EXPORT_DIR = "./api/data/export_cache";
    GRAMPSHOME = "./api/data/";
    GRAMPS_DATABASE_PATH = "./api/data/grampsdb";
    GRAMPSWEB_TREE = "Gramps Web";
    GRAMPSWEB_SECRET_KEY = "QAVoeYDzkQves9iDZ5PkxfdUoVElVMVYPqz-QXha6yE";
    GRAMPSWEB_CORS_ORIGINS = "*";
    GRAMPSWEB_VECTOR_EMBEDDING_MODEL = "sentence-transformers/distiluse-base-multilingual-cased-v2";
    GRAMPSWEB_CELERY_CONFIG__broker_url = "redis://localhost:6379/0";
    GRAMPSWEB_CELERY_CONFIG__result_backend = "redis://localhost:6379/0";
    GRAMPSWEB_LOG_LEVEL = "DEBUG";
  };

  # https://devenv.sh/packages/
  packages = with pkgs; [
    git
    gettext
    appstream
    pkg-config
    cairo
    gtk3
    gexiv2
    osm-gps-map
    gobject-introspection
    icu
    opencv
    tesseract
    pango
    postgresql.pg_config
  ];

  # https://devenv.sh/languages/
  languages = {
    javascript = {
      enable = true;
      npm = {
        enable = true;
        install.enable = true;
      };
    };
    python = {
      enable = true;
      directory = "./api";
      venv.enable = true;
    };
  };

  # https://devenv.sh/processes/
  processes = {
    gramps-web-api.exec = "python3 -O -m gramps_webapi run --port 5555 --host 0.0.0.0";
    celery.exec = "celery -A gramps_webapi.celery worker --loglevel=INFO --concurrency=1";
    gramps-web.exec = "npm run start";
  };

  # https://devenv.sh/services/
  services = {
    postgres.enable = false;
    redis.enable = true;
  };

  # https://devenv.sh/scripts/
  scripts = {
    webTasksBuild.exec = "npm run build";
  };

  enterShell = ''
    echo "Welcome to your gramps development environment!"
    git --version
    python --version
    echo -n "Node:"; node --version
  '';

  # https://devenv.sh/tasks/
  tasks = {
    "api:initSubmodule" = {
      description = "Initialize the git submodule";
      exec = ''
        git submodule init
        git submodule update
      '';
      before = [ "api:pipInstall" ];
      status = "[ -f ./api/README.md ] && exit 0 || exit 1";
    };
    "api:importData" = {
      description = "Copy gramps sample data to our data folder.";
      exec = ''
        mkdir -p ./api/data/grampsdb
        gramps -C Gramps\ Web -i $DEVENV_STATE/venv/share/doc/gramps/example/gramps/example.gramps --config=database.backend:sqlite --config=database.path:./api/data/grampsdb
        mkdir -p ./api/data/media
        cp -a $DEVENV_STATE/venv/share/doc/gramps/example/gramps/. ./api/data/media/
      '';
      status = "[ -d ./api/data/grampsdb ] && exit 0 || exit 1";
      after = [ "api:pipInstall" ];
    };
    "api:createUsers" = {
      description = "Create a test user for each role if the user db does not exist.";
      exec = ''
        python3 -m gramps_webapi user add owner owner --fullname Owner --role 4 && \
        python3 -m gramps_webapi user add editor editor --fullname Editor --role 3 && \
        python3 -m gramps_webapi user add contributor contributor --fullname Contributor --role 2 && \
        python3 -m gramps_webapi user add member member --fullname Member --role 1
      '';
      status = "[ -f ./api/instance/users.sqlite ] && exit 0 || exit 1";
      after = [ "api:pipInstall" ];
    };
    "api:pipInstall" = {
      description = "Install api dependencies via pip.";
      exec = ''
        export TMPDIR=/tmp
        pip install -r api/requirements-dev.txt
        pip install -e ./api/.[ai]
      '';
      status = "gramps --version";
    };
    "devenv:enterShell" = {
      after = [ ];
      before = [
        "api:pipInstall"
        "api:importData"
        "api:createUsers"
      ];
    };
  };

  # https://devenv.sh/tests/
  enterTest = ''
    echo "Running tests"
    git --version | grep --color=auto "${pkgs.git.version}"
  '';

  # https://devenv.sh/git-hooks/
  # git-hooks.hooks.shellcheck.enable = true;

  # See full reference at https://devenv.sh/reference/options/
}
