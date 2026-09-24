# Build with: podman build --secret id=netrc,src=$HOME/.netrc --ulimit nofile=65535:65535 . -t custom-renovate
# Run with: podman run --rm <additional args> custom-renovate renovate

FROM registry.redhat.io/rust-builder-image/rust-rhel10 AS rust

FROM registry.access.redhat.com/ubi10-minimal
LABEL description="Mintmaker - Renovate custom image" \
      summary="Mintmaker basic container image - a Renovate custom image" \
      maintainer="EXD Rebuilds Guild <exd-guild-rebuilds@redhat.com >" \
      io.k8s.description="Mintmaker - Renovate custom image" \
      com.redhat.component="mintmaker-renovate-image" \
      distribution-scope="public" \
      release="0.0.1" \
      url="https://github.com/konflux-ci/mintmaker-renovate-image/" \
      vendor="Red Hat, Inc."

# OpenShift preflight check requires licensing files under /licenses
COPY LICENSE /licenses/LICENSE

# The version number is from upstream Renovate, while the `-rpm` suffix
# is to differentiate the rpm lockfile enabled fork
ARG RENOVATE_VERSION=44.71.0-rpm

# Specific git commit hash from the redhat-exd-rebuilds/renovate fork
ARG RENOVATE_REVISION=6a2542ca879a3e0945f3090c6c3507de5345cbf7

# Version for the rpm-lockfile-prototype executable from
# https://github.com/konflux-ci/rpm-lockfile-prototype/tags
# Do not remove the following line, renovate uses it to propose version updates
# renovate: datasource=github-tags depName=konflux-ci/rpm-lockfile-prototype versioning=semver
ARG RPM_LOCKFILE_PROTOTYPE_VERSION=0.30.1

# Version for the refresh-rpm-lockfiles executable from
# https://github.com/konflux-ci/refresh-rpm-lockfiles/tags
# Do not remove the following line, renovate uses it to propose version updates
# renovate: datasource=github-tags depName=konflux-ci/refresh-rpm-lockfiles versioning=semver
ARG REFRESH_RPM_LOCKFILES_VERSION=0.1.3

# Version for the update-artifacts-lockfile executable from
# https://github.com/konflux-ci/update-artifacts-lockfile/tags
# Do not remove the following line, renovate uses it to propose version updates
# renovate: datasource=github-tags depName=konflux-ci/update-artifacts-lockfile versioning=semver
ARG UPDATE_ARTIFACTS_LOCKFILE_VERSION=0.2.0

# Version for the pipeline-migration-tool from
# https://github.com/konflux-ci/pipeline-migration-tool/tags
# Do not remove the following line, renovate uses it to propose version updates
# renovate: datasource=github-tags depName=konflux-ci/pipeline-migration-tool versioning=semver
ARG PIPELINE_MIGRATION_TOOL_VERSION=0.9.0

# Version for the tekton cli from
# https://github.com/tektoncd/cli/tags
# Do not remove the following line, renovate uses it to propose version updates
# renovate: datasource=github-tags depName=tektoncd/cli versioning=semver
ARG TEKTON_CLI_VERSION=0.46.0

# Version for the yq from
# https://github.com/mikefarah/yq/tags
# Do not remove the following line, renovate uses it to propose version updates
# renovate: datasource=github-tags depName=mikefarah/yq versioning=semver
ARG YQ_VERSION=4.53.6

# NodeJS version used for Renovate, has to satisfy the version
# specified in Renovate's package.json
ARG NODEJS_VERSION=24.20.0

ARG PNPM_VERSION=11.25.0

# Do not remove the following line, renovate uses it to propose version updates
# renovate: datasource=npm depName=yarn
ARG YARN_VERSION=1.22.22

# Do not remove the following line, renovate uses it to propose version updates
# renovate: datasource=npm depName=bun
ARG BUN_VERSION=1.3.14

# Do not remove the following line, renovate uses it to propose version updates
# renovate: datasource=rubygems depName=bundler
ARG BUNDLER_VERSION=4.0.21

# Do not remove the following line, renovate uses it to propose version updates
# renovate: datasource=pypi depName=pipx
ARG PIPX_VERSION=1.17.4

# Do not remove the following line, renovate uses it to propose version updates
# renovate: datasource=pypi depName=poetry
ARG POETRY_VERSION=2.4.3

# Do not remove the following line, renovate uses it to propose version updates
# renovate: datasource=pypi depName=pipenv
ARG PIPENV_VERSION=2026.8.0

# Do not remove the following line, renovate uses it to propose version updates
# renovate: datasource=pypi depName=hashin
ARG HASHIN_VERSION=1.0.5

# Do not remove the following line, renovate uses it to propose version updates
# renovate: datasource=pypi depName=uv
ARG UV_VERSION=0.12.17

# Do not remove the following line, renovate uses it to propose version updates
# renovate: datasource=github-tags depName=helm/helm
ARG HELM_V4_VERSION=4.3.0

# Do not remove the following line, renovate uses it to propose version updates
# renovate: datasource=github-tags depName=gradle/gradle
ARG GRADLE_VERSION=9.7.1

# Do not remove the following line, renovate uses it to propose version updates
# renovate: datasource=github-tags depName=clojure/brew-install versioning=maven
ARG CLOJURE_VERSION=1.12.6.1673

# Do not remove the following line, renovate uses it to propose version updates
# renovate: datasource=github-tags depName=sbt/sbt
ARG SBT_VERSION=1.13.0

# Do not remove the following line, renovate uses it to propose version updates
# renovate: datasource=github-tags depName=technomancy/leiningen
ARG LEININGEN_VERSION=2.13.0

# Support multiple Go versions
ENV GOTOOLCHAIN=auto

# Temporary fix for uv's cache dir permissions
ENV UV_NO_CACHE=true

# Using OpenSSL store allows for external modifications of the store. It is needed for the internal Red Hat cert.
ENV NODE_OPTIONS="--use-openssl-ca --max-old-space-size=2816"

ENV LANG=C.UTF-8

# PYENV_ROOT is also set in ~/.profile, but the file isn't always read
ENV PYENV_ROOT="/home/renovate/.pyenv"

RUN microdnf update -y && \
    microdnf install -y \
        subscription-manager-rhsm-certificates \
        git \
        nodejs24 \
        openssl \
        python3.12 \
        python3.12-pip \
        python3.14 \
        python3-dnf \
        ruby \
        golang \
        skopeo \
        jq \
        xz \
        tar \
        zip unzip \
        java-21-openjdk-devel \
        which \
        libpq-devel \
        krb5-devel && \
    microdnf clean all

# Make NodeJS 24 executables the default
RUN \
    ln -s /usr/bin/npm-24 /usr/local/bin/npm && \
    ln -s /usr/bin/node-24 /usr/local/bin/node && \
    ln -s /usr/bin/npx-24 /usr/local/bin/npx


# Install gradle
RUN curl -Lo gradle.zip https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip && \
    mkdir /opt/gradle-${GRADLE_VERSION} && unzip -d /opt/gradle-${GRADLE_VERSION} gradle.zip && \
    rm gradle.zip && \
    ln -s /opt/gradle-${GRADLE_VERSION}/gradle-${GRADLE_VERSION}/bin/gradle /usr/bin/gradle

# Install Clojure
RUN curl -Lo install-clojure.sh https://github.com/clojure/brew-install/releases/download/${CLOJURE_VERSION}/linux-install.sh && \
    chmod +x install-clojure.sh && ./install-clojure.sh && rm install-clojure.sh

# Install sbt
RUN curl -Lo sbt.tgz https://github.com/sbt/sbt/releases/download/v${SBT_VERSION}/sbt-${SBT_VERSION}.tgz && \
    mkdir /opt/sbt-v${SBT_VERSION} && tar xf sbt.tgz -C /opt/sbt-v${SBT_VERSION} && \
    rm sbt.tgz && \
    ln -s /opt/sbt-v${SBT_VERSION}/sbt/bin/sbt /usr/bin/sbt

# Install Lieningen
RUN curl -Lo /usr/bin/lein https://raw.githubusercontent.com/technomancy/leiningen/stable/bin/lein && chmod +x /usr/bin/lein

# Add renovate user and switch to it
RUN useradd -lms /bin/bash -u 1001 -g 0 renovate
RUN mkdir -p /home/renovate/.cache /home/renovate/.local /home/renovate/.local/state/pdm /home/renovate/.rustup/tmp /home/renovate/.local/share/pnpm/.tools/pnpm
RUN chown -R 1001:0 /home/renovate && chmod -R 2775 /home/renovate

WORKDIR /home/renovate
USER 1001

# Enable renovate user's bin dirs,
#   ~/.local/bin for Python executables
#   ~/node_modules/.bin for renovate
ENV PATH="/home/renovate/.local/bin:/home/renovate/node_modules/.bin:/home/renovate/go/bin:/home/renovate/.pyenv/bin:/tmp/renovate/cache/others/go/bin:/usr/local/share/rust/bin:${PATH}"

# Install package managers
RUN npm install pnpm@${PNPM_VERSION} bun@${BUN_VERSION} && npm cache clean --force

# Install yarn
RUN \
    git clone --depth 1 --branch v${YARN_VERSION} https://github.com/yarnpkg/yarn.git /tmp/yarn && \
    pushd /tmp/yarn && \
    npm install --legacy-peer-deps --no-package-lock && \
    npm run build-bundle && \
    chmod +x artifacts/yarn-${YARN_VERSION}.js && \
    mkdir -p /home/renovate/.local/bin && \
    mv artifacts/yarn-${YARN_VERSION}.js /home/renovate/.local/bin/yarn && \
    cp /home/renovate/.local/bin/yarn /home/renovate/.local/bin/yarnpkg && \
    popd && \
    rm -rf /tmp/yarn

# Install bundler
RUN \
    git clone --depth 1 --branch v${BUNDLER_VERSION} https://github.com/ruby/rubygems.git /tmp/bundler-cli && \
    gem -C /tmp/bundler-cli/bundler build bundler.gemspec && \
    gem install --local "/tmp/bundler-cli/bundler/bundler-${BUNDLER_VERSION}.gem" && \
    rm -rf '/tmp/bundler-cli'

# Use virtualenv isolation to avoid dependency issues with other global packages
RUN pip3.12 install --user pipx==${PIPX_VERSION} && pip3.12 cache purge
RUN pipx install --python python3.12 poetry==${POETRY_VERSION} pipenv==${PIPENV_VERSION} \
    hashin==${HASHIN_VERSION} uv==${UV_VERSION} \
    git+https://github.com/konflux-ci/pipeline-migration-tool.git@v${PIPELINE_MIGRATION_TOOL_VERSION}\
    && pipx inject hashin certifi\
    && rm -fr ~/.cache/pipx && pip3.12 cache purge

COPY install-python-tool.sh /home/renovate/install-python-tool.sh
COPY --chown=1001:0 tools /tmp/tools
RUN --mount=type=secret,id=netrc,target=/home/renovate/.netrc,uid=1001,gid=0,mode=0400 \
    ./install-python-tool.sh /tmp/tools/hatch/requirements.txt && \
    ./install-python-tool.sh /tmp/tools/pdm/requirements.txt && \
    ./install-python-tool.sh /tmp/tools/pip-tools/requirements.txt pip-compile pip-sync && \
    rm -rf /tmp/tools /home/renovate/install-python-tool.sh

# Install pyenv
RUN curl https://pyenv.run | sh
RUN echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.profile && \
    echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.profile && \
    echo 'eval "$(pyenv init -)"' >> ~/.profile

# Install additional Python versions
COPY install-python.sh /home/renovate/install-python.sh

# Download prebuilt CPython
RUN ./install-python.sh 3.10
RUN ./install-python.sh 3.11
RUN ./install-python.sh 3.13

# Ensure Python requests library uses system root certificates
# Particularly important for Python virtual environments
ENV REQUESTS_CA_BUNDLE=/etc/pki/tls/certs/ca-bundle.crt

# Set paths for openssl/urllib
ENV SSL_CERT_FILE=/etc/pki/tls/certs/ca-bundle.crt
ENV SSL_CERT_DIR=/etc/pki/tls/certs

# Update paths
ENV PATH="${PATH}:/home/renovate/python3.10/bin:/home/renovate/python3.11/bin:/home/renovate/python3.13/bin"

# Install Go-based packages from source:
# * helmv4
# * yq
# * jsonnet-bundler
# * tekton cli
RUN \
    go install -a helm.sh/helm/v4/cmd/helm@v${HELM_V4_VERSION} && \
    go install -a github.com/mikefarah/yq/v4@v${YQ_VERSION} && \
    go install -a github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb@latest && \
    # Tekton CLI requires special handling due to its `replace` directives in go.mod \
    git clone --depth 1 --branch v${TEKTON_CLI_VERSION} https://github.com/tektoncd/cli.git '/tmp/tkn-cli' && \
    go -C '/tmp/tkn-cli' install -mod=vendor \
        -ldflags "-X github.com/tektoncd/cli/pkg/cmd/version.clientVersion=v${TEKTON_CLI_VERSION}" \
        ./cmd/tkn && \
    rm -rf '/tmp/tkn-cli' && \
    go clean -cache -modcache

# Install the latest Rust toolchain
COPY --from=rust /usr/local/share/rust /usr/local/share/rust

WORKDIR /home/renovate/renovate

# Clone Renovate from the fork and checkout the specific commit that includes custom
# features for RPM lockfile support and Red Hat Container/RPM vulnerability alerts
RUN git clone --depth=1 --branch renovate-43-268-1 https://github.com/redhat-exd-rebuilds/renovate.git . \
    && git fetch --depth 1 origin ${RENOVATE_REVISION} \
    && git checkout ${RENOVATE_REVISION}

# Replace package.json version for this build
RUN sed -i "s/0.0.0-semantic-release/${RENOVATE_VERSION}/g" package.json
# Install project dependencies, build and install Renovate
RUN pnpm install && pnpm build \
    && PNPM_HOME=/home/renovate/.local pnpm add -g . \
    && pnpm prune --prod --ignore-scripts \
    && pnpm store prune \
    && npm cache clean --force

# Run pipx install with the --system-site-packages so rpm-lockfile-prototype can use the system's python3-dnf package
RUN pipx install --python python3.12 git+https://github.com/konflux-ci/rpm-lockfile-prototype.git@v${RPM_LOCKFILE_PROTOTYPE_VERSION} --system-site-packages && \
    rm -fr ~/.cache/pipx && pip3.12 cache purge

RUN pipx install --python python3.12 git+https://github.com/konflux-ci/refresh-rpm-lockfiles.git@v${REFRESH_RPM_LOCKFILES_VERSION} && \
    rm -fr ~/.cache/pipx && pip3.12 cache purge

RUN pipx install --python python3.12 git+https://github.com/konflux-ci/update-artifacts-lockfile.git@v${UPDATE_ARTIFACTS_LOCKFILE_VERSION} && \
    rm -fr ~/.cache/pipx && pip3.12 cache purge

WORKDIR /workspace
