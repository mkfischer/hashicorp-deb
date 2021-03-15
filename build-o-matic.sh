#!/bin/sh
set -ex

export cwd="$(pwd)"
export __dirname="$(dirname "$(realpath "$0")")"
export os="linux"
export arch="arm64"
export name="$(jq -r '.name' package.json)"
export version="$(jq -r '.version' package.json)"
export description="$(jq -r '.description' package.json)"
export maintainer="$(jq -r '.author' package.json)"
export host="releases.hashicorp.com"
export keyuid="HashiCorp Security <security@hashicorp.com>"
export keyprint="91A6E7F85D05C65630BEF18951852D87348FFC4C"
export bin='/usr/bin'
export sha='256'
export base="${name}_${version}"
export zipfile="${base}_${os}_${arch}.zip"
export sumfile="${base}_SHA${sha}SUMS"
export sigfile="${base}_SHA${sha}SUMS.sig"
export builds="${cwd}/.builds"
export downloads="${cwd}/.downloads"
export packages="${cwd}/.packages"

__dirname="$(dirname "$(realpath "$0")")"
. "${__dirname}/context"

echo "installing signing key"
curl https://keybase.io/hashicorp/key.asc | gpg --import

__dirname="$(dirname "$(realpath "$0")")"
. "${__dirname}/context"

mkdir -p "${downloads}"
cd "${downloads}"

# download compressed binary, checksum, and signature
if ! test -e "${zipfile}"
then
  echo "downloading ${zipfile}"
  curl -O "https://${host}/${name}/${version}/${zipfile}"
fi

if ! test -e "${sumfile}"
then
  echo "downloading ${sumfile}"
  curl -O "https://${host}/${name}/${version}/${sumfile}"
fi

if ! test -e "${sigfile}"
then
  echo "downloading ${sigfile}"
  curl -O "https://${host}/${name}/${version}/${sigfile}"
fi

# verify checksum with signature
echo "verifying ${sumfile} with ${sigfile}"
gpg --verify "${sigfile}" "${sumfile}"
if test "$?" != "0"
then
  echo "${name} signature doesn't match key"
  exit 1
fi

# verify compressed binary with checksum
cat "${sumfile}" | grep "${zipfile}" | shasum -a "${sha}" -c -
if test "$?" != "0"
then
  echo "${name} binary doesn't match sha${sha}sum"
  exit 1
fi

cd "${cwd}"

mkdir -p "${builds}"
cd "${builds}"

rm -rf "${base}"

template="Package: ${name}
Description: ${description}
Version: ${version}
Maintainer: ${maintainer}
Architecture: ${arch}
Section: base
Priority: optional"

mkdir -p "${base}/DEBIAN"
echo "${template}" > "${base}/DEBIAN/control"

mkdir -p "${base}${bin}"
unzip "${downloads}/${zipfile}" -d "${base}${bin}"
#sudo chown -R "root:root" "${base}"

cd "${cwd}"

__dirname="$(dirname "$(realpath "$0")")"
. "${__dirname}/context"

mkdir -p "${packages}"

dpkg-deb --build "${builds}/${base}" "${packages}"
