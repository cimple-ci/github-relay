cimple {
  version = "0.0.4"
}

name = "Cimple Github Relay"
description = "Relays Github webhook requests to a CimpleCI Server"
version = "0.0.4"

env {
  GOPATH = "{{index .HostEnv \"GOPATH\"}}"
  GOROOT = "{{index .HostEnv \"GOROOT\"}}"
  # PATH required for glide command (needs access to Git).
  # Should PATH always be mapped by default?
  PATH = "{{index .HostEnv \"PATH\"}}"
  VERSION_LABEL = "{{if ne (index .Vcs.Branch) \"master\"}}{{index .Vcs.Branch}}-{{index .Vcs.Revision}}{{end}}"
}

task fix {
  script gofmt {
    body = "go fmt main.go"
  }
}

task package {
  description = "Packages Cimple for release"
  depends = ["test", "fix"]

  command clean {
    command = "rm"
    args = ["-rf", "output"]
  }

  script compile {
    body = <<BODY
#!/bin/bash
compile() {
  echo Compiling $1 $2
  env GOOS=$1 GOARCH=$2 go build -o output/cimple-github-relay_{{index .Project.Version}}_$1_$2 \
    -ldflags="-X main.VERSION={{index .Project.Version}} -X main.BuildDate={{index .FormattedBuildDate}} -X main.Revision={{index .Vcs.Revision}}" \
    main.go
}

tar_pack() {
  echo Tar packing $1 $2
  cp output/cimple-github-relay_{{index .Project.Version}}_$1_$2 output/cimple-github-relay
  tar -czf output/downloads/{{index .Project.Version}}/cimple-github-relay_{{index .Project.Version}}_$1_$2.tar.gz --directory="$PWD/output" cimple-github-relay
}

zip_pack() {
  echo Zipping $1 $2
  cd output
  cp cimple-github-relay_{{index .Project.Version}}_$1_$2 cimple-github-relay
  zip cimple-github-relay_{{index .Project.Version}}_$1_$2.zip cimple-github-relay > /dev/null
  mv cimple-github-relay_{{index .Project.Version}}_$1_$2.zip downloads/{{index .Project.Version}}/cimple-github-relay_{{index .Project.Version}}_$1_$2.zip
  cd - > /dev/null
}

mkdir -p output/downloads/{{index .Project.Version}}
compile linux amd64
tar_pack linux amd64
compile linux 386
tar_pack linux 386
compile linux arm
tar_pack linux arm
compile darwin amd64
zip_pack darwin amd64
compile darwin 386
zip_pack darwin 386
compile windows amd64
zip_pack windows amd64
compile windows 386
zip_pack windows 386
BODY
  }

  script build-cimple-docker {
    body = <<SCRIPT
{{ if ne (index .Vcs.Branch) "master" }}
docker build --build-arg CIMPLE_GITHUB_RELAY_VERSION={{index .Project.Version}}-$VERSION_LABEL -t cimple-github-relay -f Dockerfile .
{{ else }}
docker build --build-arg CIMPLE_GITHUB_RELAY_VERSION={{index .Project.Version}} -t cimple-github-relay -f Dockerfile .
{{ end }}
SCRIPT
  }

  script tag-cimple-docker {
    body = <<SCRIPT
{{ if ne (index .Vcs.Branch) "master" }}
docker tag cimpleci/cimple-github-relay:latest cimpleci/cimple-github-relay:{{index .Project.Version}}-$VERSION_LABEL
{{ else }}
docker tag cimple-github-relay cimpleci/cimple-github-relay:latest
docker tag cimpleci/cimple-github-relay:latest cimpleci/cimple-github-relay:{{index .Project.Version}}
{{ end }}
SCRIPT
  }
}

task publish {
  depends = ["package"]
  limit_to = "server"

  script publish-docker {
    body = <<SCRIPT
{{ if ne (index .Vcs.Branch) "master" }}
docker push cimpleci/cimple-github-relay:{{index .Project.Version}}-$VERSION_LABEL
{{ else }}
docker push cimpleci/cimple-github-relay:latest
docker push cimpleci/cimple-github-relay:{{index .Project.Version}}
{{ end }}
SCRIPT
  }

  publish binaries {
    destination bintray {
      subject = "cimpleci"
      repository = "pkgs"
      package = "cimple-github-relay"
      username = "lukesmith"
    }
    files = [
      "output/downloads/{{index .Project.Version}}*/cimple-github-relay_{{index .Project.Version}}*.tar.gz",
      "output/downloads/{{index .Project.Version}}*/cimple-github-relay_{{index .Project.Version}}*.zip"
    ]
  }
}
