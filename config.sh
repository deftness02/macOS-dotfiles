#!/bin/sh

###############################################################################
# Configuration                                                               #
###############################################################################

# This file is based largely upon the efforts of:
# 
# See my repo readme for more credits:
# https://github.com/leftygamer02/macOS-dotfiles

###############################################################################
# Quick Start                                                                 #
###############################################################################

case "${SHELL}" in
  (*zsh) ;;
  (*) chsh -s "$(which zsh)"; exit 1 ;;
esac

###############################################################################
# Initialize New Terminal                                                     #
###############################################################################

if test -z "${1}"; then
  osascript - "${0}" << EOF > /dev/null 2>&1
    on run { _this }
      tell app "Terminal" to do script "source " & quoted form of _this & " 0"
    end run
EOF
fi

###############################################################################
# Define Function =ask=                                                       #
###############################################################################

ask () {
  osascript - "${1}" "${2}" "${3}" << EOF 2> /dev/null
    on run { _title, _action, _default }
      tell app "System Events" to return text returned of (display dialog _title with title _title buttons { "Cancel", _action } default answer _default)
    end run
EOF
}

###############################################################################
# Define Function =ask2=                                                      #
###############################################################################

ask2 () {
  osascript - "$1" "$2" "$3" "$4" "$5" "$6" << EOF 2> /dev/null
on run { _text, _title, _cancel, _action, _default, _hidden }
  tell app "Terminal" to return text returned of (display dialog _text with title _title buttons { _cancel, _action } cancel button _cancel default button _action default answer _default hidden answer _hidden)
end run
EOF
}

###############################################################################
# Define Function =p=                                                         #
###############################################################################

p () {
  printf "\n\033[1m\033[34m%s\033[0m\n\n" "${1}"
}

###############################################################################
# Define Function =run=                                                       #
###############################################################################

run () {
  osascript - "${1}" "${2}" "${3}" << EOF 2> /dev/null
    on run { _title, _cancel, _action }
      tell app "Terminal" to return button returned of (display dialog _title with title _title buttons { _cancel, _action } cancel button 1 default button 2 giving up after 5)
    end run
EOF
}

###############################################################################
# Define Function =init=                                                      #
###############################################################################

init () {
  init_sudo
  init_cache
  init_no_sleep
  init_hostname
  init_perms
  init_maskeep
  init_updates

  config_new_account
  config_rm_sudoers
}

if test "${1}" = 0; then
  printf "\n$(which init)\n"
fi

###############################################################################
# Define Function =init_paths=                                                #
###############################################################################

init_paths () {
  test -x "/usr/libexec/path_helper" && \
    eval $(/usr/libexec/path_helper -s)
}

###############################################################################
# Eliminate Prompts for Password                                              #
###############################################################################

init_sudo () {
  printf "%s\n" "%wheel ALL=(ALL) NOPASSWD: ALL" | \
  sudo tee "/etc/sudoers.d/wheel" > /dev/null && \
  sudo dscl /Local/Default append /Groups/wheel GroupMembership "$(whoami)"
}

###############################################################################
# Select Installation Cache Location                                          #
###############################################################################

init_cache () {
  grep -q "CACHES" "/etc/zshenv" 2> /dev/null || \
  a=$(osascript << EOF 2> /dev/null
    on run
      return text 1 through -2 of POSIX path of (choose folder with prompt "Select Installation Cache Location")
    end run
EOF
) && \
  test -d "${a}" || \
    a="${HOME}/Library/Caches/"

  grep -q "CACHES" "/etc/zshenv" 2> /dev/null || \
  printf "%s\n" \
    "export CACHES=\"${a}\"" \
    "export HOMEBREW_CACHE=\"${a}/brew\"" \
    "export BREWFILE=\"${a}/brew/Brewfile\"" | \
  sudo tee -a "/etc/zshenv" > /dev/null
  . "/etc/zshenv"

  if test -d "${CACHES}/upd"; then
    sudo chown -R "$(whoami)" "/Library/Updates"
    rsync -a --delay-updates \
      "${CACHES}/upd/" "/Library/Updates/"
  fi
}

###############################################################################
# Set Hostname from DNS                                                       #
###############################################################################

init_hostname () {
  a=$(ask2 "Set Computer Name and Hostname" "Set Hostname" "Cancel" "Set Hostname" $(ruby -e "print '$(hostname -s)'.capitalize") "false")
  if test -n $a; then
    sudo scutil --set ComputerName $(ruby -e "print '$a'.capitalize")
    sudo scutil --set HostName $(ruby -e "print '$a'.downcase")
  fi
}

###############################################################################
# Set Permissions on Install Destinations                                     #
###############################################################################

_dest='/usr/local/bin
/Library/Desktop Pictures
/Library/ColorPickers
/Library/Fonts
/Library/Input Methods
/Library/PreferencePanes
/Library/QuickLook
/Library/Screen Savers
/Library/User Pictures'

init_perms () {
  printf "%s\n" "${_dest}" | \
  while IFS="$(printf '\t')" read d; do
    test -d "${d}" || sudo mkdir -p "${d}"
    sudo chgrp -R admin "${d}"
    sudo chmod -R g+w "${d}"
  done
}

###############################################################################
# Install Developer Tools                                                     #
###############################################################################

init_devtools () {
  xcode-select --install
}

###############################################################################
# Install Xcode                                                               #
###############################################################################

init_xcode () {
  if test -f ${HOMEBREW_CACHE}/Cask/xcode*.xip; then
    p "Installing Xcode"
    dest="${HOMEBREW_CACHE}/Cask/xcode"
    if ! test -d "$dest"; then
      pkgutil --expand ${HOMEBREW_CACHE}/Cask/xcode*.xip "$dest"
      curl --location --silent \
        "https://gist.githubusercontent.com/pudquick/ff412bcb29c9c1fa4b8d/raw/24b25538ea8df8d0634a2a6189aa581ccc6a5b4b/parse_pbzx2.py" | \
        python - "${dest}/Content"
      find "${dest}" -empty -name "*.xz" -type f -print0 | \
        xargs -0 -l 1 rm
      find "${dest}" -name "*.xz" -print0 | \
        xargs -0 -L 1 gunzip
      cat ${dest}/Content.part* > \
        ${dest}/Content.cpio
    fi
    cd /Applications && \
      sudo cpio -dimu --file=${dest}/Content.cpio
    for pkg in /Applications/Xcode*.app/Contents/Resources/Packages/*.pkg; do
      sudo installer -pkg "$pkg" -target /
    done
    x="$(find '/Applications' -maxdepth 1 -regex '.*/Xcode[^ ]*.app' -print -quit)"
    if test -n "${x}"; then
      sudo xcode-select -s "${x}"
      sudo xcodebuild -license accept
    fi
  fi
}

###############################################################################
# Install macOS Updates                                                       #
###############################################################################

init_updates () {
  sudo softwareupdate --install --all
}

# Save Mac App Store Packages
# #+begin_example sh
# sudo lsof -c softwareupdated -F -r 2 | sed '/^n\//!d;/com.apple.SoftwareUpdate/!d;s/^n//'
# sudo lsof -c storedownloadd -F -r 2 | sed '/^n\//!d;/com.apple.appstore/!d;s/^n//'
# #+end_example

_maskeep_launchd='add	:KeepAlive	bool	false
add	:Label	string	com.github.ptb.maskeep
add	:ProcessType	string	Background
add	:Program	string	/usr/local/bin/maskeep
add	:RunAtLoad	bool	true
add	:StandardErrorPath	string	/dev/stderr
add	:StandardOutPath	string	/dev/stdout
add	:UserName	string	root
add	:WatchPaths	array	
add	:WatchPaths:0	string	$(sudo find '"'"'/private/var/folders'"'"' -name '"'"'com.apple.SoftwareUpdate'"'"' -type d -user _softwareupdate -print -quit 2> /dev/null)
add	:WatchPaths:1	string	$(sudo -u \\#501 -- sh -c '"'"'getconf DARWIN_USER_CACHE_DIR'"'"' 2> /dev/null)com.apple.appstore
add	:WatchPaths:2	string	$(sudo -u \\#502 -- sh -c '"'"'getconf DARWIN_USER_CACHE_DIR'"'"' 2> /dev/null)com.apple.appstore
add	:WatchPaths:3	string	$(sudo -u \\#503 -- sh -c '"'"'getconf DARWIN_USER_CACHE_DIR'"'"' 2> /dev/null)com.apple.appstore
add	:WatchPaths:4	string	/Library/Updates'

init_maskeep () {
  sudo softwareupdate --reset-ignored > /dev/null

  cat << EOF > "/usr/local/bin/maskeep"
#!/bin/sh
asdir="/Library/Caches/storedownloadd"
as1="\$(sudo -u \\#501 -- sh -c 'getconf DARWIN_USER_CACHE_DIR' 2> /dev/null)com.apple.appstore"
as2="\$(sudo -u \\#502 -- sh -c 'getconf DARWIN_USER_CACHE_DIR' 2> /dev/null)com.apple.appstore"
as3="\$(sudo -u \\#503 -- sh -c 'getconf DARWIN_USER_CACHE_DIR' 2> /dev/null)com.apple.appstore"
upd="/Library/Updates"
sudir="/Library/Caches/softwareupdated"
su="\$(sudo find '/private/var/folders' -name 'com.apple.SoftwareUpdate' -type d -user _softwareupdate 2> /dev/null)"
for i in 1 2 3 4 5; do
  mkdir -m a=rwxt -p "\$asdir"
  for as in "\$as1" "\$as2" "\$as3" "\$upd"; do
    test -d "\$as" && \
    find "\${as}" -type d -print | \\
    while read a; do
      b="\${asdir}/\$(basename \$a)"
      mkdir -p "\${b}"
      find "\${a}" -type f -print | \\
      while read c; do
        d="\$(basename \$c)"
        test -e "\${b}/\${d}" || \\
          ln "\${c}" "\${b}/\${d}" && \\
          chmod 666 "\${b}/\${d}"
      done
    done
  done
  mkdir -m a=rwxt -p "\${sudir}"
  find "\${su}" -name "*.tmp" -type f -print | \\
  while read a; do
    d="\$(basename \$a)"
    test -e "\${sudir}/\${d}.xar" ||
      ln "\${a}" "\${sudir}/\${d}.xar" && \\
      chmod 666 "\${sudir}/\${d}.xar"
  done
  sleep 1
done
exit 0
EOF

  chmod a+x "/usr/local/bin/maskeep"
  rehash

  config_launchd "/Library/LaunchDaemons/com.github.ptb.maskeep.plist" "$_maskeep_launchd" "sudo" ""
}

###############################################################################
# Define Function =install=                                                   #
###############################################################################

install () {
  install_macos_sw
  install_node_sw
  install_perl_sw
  install_python_sw
  install_ruby_sw

  which config
}

###############################################################################
# Install macOS Software with =brew=                                          #
###############################################################################

install_macos_sw () {
  p "Installing macOS Software"
  install_paths
  install_brew
  install_brewfile_taps
  install_brewfile_brew_pkgs
  install_brewfile_cask_args
  install_brewfile_cask_pkgs
  install_brewfile_mas_apps

  x=$(find '/Applications' -maxdepth 1 -regex '.*/Xcode[^ ]*.app' -print -quit)
  if test -n "$x"; then
    sudo xcode-select -s "$x"
    sudo xcodebuild -license accept
  fi

  brew bundle --file="${BREWFILE}"

  x=$(find '/Applications' -maxdepth 1 -regex '.*/Xcode[^ ]*.app' -print -quit)
  if test -n "$x"; then
    sudo xcode-select -s "$x"
    sudo xcodebuild -license accept
  fi

  install_links
  sudo xattr -rd "com.apple.quarantine" "/Applications" > /dev/null 2>&1
  sudo chmod -R go=u-w "/Applications" > /dev/null 2>&1
}

###############################################################################
# Add =/usr/local/bin/sbin= to Default Path                                   #
###############################################################################

install_paths () {
  if ! grep -Fq "/usr/local/sbin" /etc/paths; then
    sudo sed -i "" -e "/\/usr\/sbin/{x;s/$/\/usr\/local\/sbin/;G;}" /etc/paths
  fi
}

###############################################################################
# Link System Utilities to Applications                                       #
###############################################################################

_links='/System/Library/CoreServices/Applications
/Applications/Xcode.app/Contents/Applications
/Applications/Xcode.app/Contents/Developer/Applications
/Applications/Xcode-beta.app/Contents/Applications
/Applications/Xcode-beta.app/Contents/Developer/Applications'

install_links () {
  printf "%s\n" "${_links}" | \
  while IFS="$(printf '\t')" read link; do
    find "${link}" -maxdepth 1 -name "*.app" -type d -print0 2> /dev/null | \
    xargs -0 -I {} -L 1 ln -s "{}" "/Applications" 2> /dev/null
  done
}

###############################################################################
# Install Node.js with =nodenv=                                               #
###############################################################################

_npm='eslint
eslint-config-cleanjs
eslint-plugin-better
eslint-plugin-fp
eslint-plugin-import
eslint-plugin-json
eslint-plugin-promise
eslint-plugin-standard
gatsby
json
sort-json'

install_node_sw () {
  if which nodenv > /dev/null; then
    NODENV_ROOT="/usr/local/node" && export NODENV_ROOT

    sudo mkdir -p "$NODENV_ROOT"
    sudo chown -R "$(whoami):admin" "$NODENV_ROOT"

    p "Installing Node.js with nodenv"
    git clone https://github.com/nodenv/node-build-update-defs.git \
      "$(nodenv root)"/plugins/node-build-update-defs
    nodenv update-version-defs > /dev/null

    nodenv install --skip-existing 8.7.0
    nodenv global 8.7.0

    grep -q "${NODENV_ROOT}" "/etc/paths" || \
    sudo sed -i "" -e "1i\\
${NODENV_ROOT}/shims
" "/etc/paths"

    init_paths
    rehash
  fi

  T=$(printf '\t')

  printf "%s\n" "$_npm" | \
  while IFS="$T" read pkg; do
    npm install --global "$pkg"
  done

  rehash
}

###############################################################################
# Install Perl 5 with =plenv=                                                 #
###############################################################################

install_perl_sw () {
  if which plenv > /dev/null; then
    PLENV_ROOT="/usr/local/perl" && export PLENV_ROOT

    sudo mkdir -p "$PLENV_ROOT"
    sudo chown -R "$(whoami):admin" "$PLENV_ROOT"

    p "Installing Perl 5 with plenv"
    plenv install 5.26.0 > /dev/null 2>&1
    plenv global 5.26.0

    grep -q "${PLENV_ROOT}" "/etc/paths" || \
    sudo sed -i "" -e "1i\\
${PLENV_ROOT}/shims
" "/etc/paths"

    init_paths
    rehash
  fi
}

###############################################################################
# Install Python with =pyenv=                                                     #
###############################################################################

install_python_sw () {
  if which pyenv > /dev/null; then
    CFLAGS="-I$(brew --prefix openssl)/include" && export CFLAGS
    LDFLAGS="-L$(brew --prefix openssl)/lib" && export LDFLAGS
    PYENV_ROOT="/usr/local/python" && export PYENV_ROOT

    sudo mkdir -p "$PYENV_ROOT"
    sudo chown -R "$(whoami):admin" "$PYENV_ROOT"

    p "Installing Python 2 with pyenv"
    pyenv install --skip-existing 2.7.13
    p "Installing Python 3 with pyenv"
    pyenv install --skip-existing 3.6.2
    pyenv global 2.7.13

    grep -q "${PYENV_ROOT}" "/etc/paths" || \
    sudo sed -i "" -e "1i\\
${PYENV_ROOT}/shims
" "/etc/paths"

    init_paths
    rehash

    pip install --upgrade "pip" "setuptools"

    # Reference: https://github.com/mdhiggins/sickbeard_mp4_automator
    pip install --upgrade "babelfish" "guessit<2" "qtfaststart" "requests" "stevedore==1.19.1" "subliminal<2"
    pip install --upgrade "requests-cache" "requests[security]"

    # Reference: https://github.com/pixelb/crudini
    pip install --upgrade "crudini"
  fi
}

###############################################################################
# Install Ruby with =rbenv=                                                   #
###############################################################################

install_ruby_sw () {
  if which rbenv > /dev/null; then
    RBENV_ROOT="/usr/local/ruby" && export RBENV_ROOT

    sudo mkdir -p "$RBENV_ROOT"
    sudo chown -R "$(whoami):admin" "$RBENV_ROOT"

    p "Installing Ruby with rbenv"
    rbenv install --skip-existing 2.4.2
    rbenv global 2.4.2

    grep -q "${RBENV_ROOT}" "/etc/paths" || \
    sudo sed -i "" -e "1i\\
${RBENV_ROOT}/shims
" "/etc/paths"

    init_paths
    rehash

    printf "%s\n" \
      "gem: --no-document" | \
    tee "${HOME}/.gemrc" > /dev/null

    gem update --system > /dev/null

    trash "$(which rdoc)"
    trash "$(which ri)"
    gem update

    gem install bundler
  fi
}

###############################################################################
# Define Function =config=                                                    #
###############################################################################

config () {
  config_admin_req
  config_bbedit
  config_emacs
  config_environment
  config_ipmenulet
  config_istatmenus
  config_nginx
  config_openssl
  config_sysprefs
  config_zsh
  config_guest

  which custom
}

###############################################################################
# Define Function =config_defaults=                                           #
###############################################################################

config_defaults () {
  printf "%s\n" "${1}" | \
  while IFS="$(printf '\t')" read domain key type value host; do
    ${2} defaults ${host} write ${domain} "${key}" ${type} "${value}"
  done
}

###############################################################################
# Define Function =config_plist=                                              #
###############################################################################

T="$(printf '\t')"

config_plist () {
  printf "%s\n" "$1" | \
  while IFS="$T" read command entry type value; do
    case "$value" in
      (\$*)
        $4 /usr/libexec/PlistBuddy "$2" \
          -c "$command '${3}${entry}' $type '$(eval echo \"$value\")'" 2> /dev/null ;;
      (*)
        $4 /usr/libexec/PlistBuddy "$2" \
          -c "$command '${3}${entry}' $type '$value'" 2> /dev/null ;;
    esac
  done
}

###############################################################################
# Define Function =config_launchd=                                            #
###############################################################################

config_launchd () {
  test -d "$(dirname $1)" || \
    $3 mkdir -p "$(dirname $1)"

  test -f "$1" && \
    $3 launchctl unload "$1" && \
    $3 rm -f "$1"

  config_plist "$2" "$1" "$4" "$3" && \
    $3 plutil -convert xml1 "$1" && \
    $3 launchctl load "$1"
}

###############################################################################
# Mark Applications Requiring Administrator Account                           #
###############################################################################

_admin_req='Automator.app
Keychain Access.app
Maps.app
Music.app
News.app
Stocks.app
Home.app
TV.app
Apple Configurator.app
Chess.app
Freeform.app
iMazing Profile Editor.app
Siri.app'

config_admin_req () {
  printf "%s\n" "${_admin_req}" | \
  while IFS="$(printf '\t')" read app; do
    sudo tag -a "Red, admin" "/Applications/${app}"
  done
}

###############################################################################
# Configure BBEdit                                                            #
###############################################################################

config_bbedit () {
  if test -d "/Applications/BBEdit.app"; then
    test -f "/usr/local/bin/bbdiff" || \
    ln /Applications/BBEdit.app/Contents/Helpers/bbdiff /usr/local/bin/bbdiff && \
    ln /Applications/BBEdit.app/Contents/Helpers/bbedit_tool /usr/local/bin/bbedit && \
    ln /Applications/BBEdit.app/Contents/Helpers/bbfind /usr/local/bin/bbfind && \
    ln /Applications/BBEdit.app/Contents/Helpers/bbresults /usr/local/bin/bbresults
  fi
}

###############################################################################
# Configure Default Apps                                                      #
###############################################################################

config_default_apps () {
  true
}

############################################### This is where you're at
######################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################

# Configure Environment Variables

_environment_defaults='/Library/LaunchAgents/environment.user	KeepAlive	-bool	false	
/Library/LaunchAgents/environment.user	Label	-string	environment.user	
/Library/LaunchAgents/environment.user	ProcessType	-string	Background	
/Library/LaunchAgents/environment.user	Program	-string	/etc/environment.sh	
/Library/LaunchAgents/environment.user	RunAtLoad	-bool	true	
/Library/LaunchAgents/environment.user	WatchPaths	-array-add	/etc/environment.sh	
/Library/LaunchAgents/environment.user	WatchPaths	-array-add	/etc/paths	
/Library/LaunchAgents/environment.user	WatchPaths	-array-add	/etc/paths.d	
/Library/LaunchDaemons/environment	KeepAlive	-bool	false	
/Library/LaunchDaemons/environment	Label	-string	environment	
/Library/LaunchDaemons/environment	ProcessType	-string	Background	
/Library/LaunchDaemons/environment	Program	-string	/etc/environment.sh	
/Library/LaunchDaemons/environment	RunAtLoad	-bool	true	
/Library/LaunchDaemons/environment	WatchPaths	-array-add	/etc/environment.sh	
/Library/LaunchDaemons/environment	WatchPaths	-array-add	/etc/paths	
/Library/LaunchDaemons/environment	WatchPaths	-array-add	/etc/paths.d	'
config_environment () {
  sudo tee "/etc/environment.sh" << 'EOF' > /dev/null
#!/bin/sh
set -e
if test -x /usr/libexec/path_helper; then
  export PATH=""
  eval `/usr/libexec/path_helper -s`
  launchctl setenv PATH $PATH
fi
osascript -e 'tell app "Dock" to quit'
EOF
  sudo chmod a+x "/etc/environment.sh"
  rehash

  la="/Library/LaunchAgents/environment.user"
  ld="/Library/LaunchDaemons/environment"

  sudo mkdir -p "$(dirname $la)" "$(dirname $ld)"
  sudo launchctl unload "${la}.plist" "${ld}.plist" 2> /dev/null
  sudo rm -f "${la}.plist" "${ld}.plist"

  config_defaults "$_environment_defaults" "sudo"
  sudo plutil -convert xml1 "${la}.plist" "${ld}.plist"
  sudo launchctl load "${la}.plist" "${ld}.plist" 2> /dev/null
}

# Configure nginx

_nginx_defaults='/Library/LaunchDaemons/org.nginx.nginx	KeepAlive	-bool	true	
/Library/LaunchDaemons/org.nginx.nginx	Label	-string	org.nginx.nginx	
/Library/LaunchDaemons/org.nginx.nginx	ProcessType	-string	Background	
/Library/LaunchDaemons/org.nginx.nginx	Program	-string	/usr/local/bin/nginx	
/Library/LaunchDaemons/org.nginx.nginx	RunAtLoad	-bool	true	
/Library/LaunchDaemons/org.nginx.nginx	StandardErrorPath	-string	/usr/local/var/log/nginx/error.log	
/Library/LaunchDaemons/org.nginx.nginx	StandardOutPath	-string	/usr/local/var/log/nginx/access.log	
/Library/LaunchDaemons/org.nginx.nginx	UserName	-string	root	
/Library/LaunchDaemons/org.nginx.nginx	WatchPaths	-array-add	/usr/local/etc/nginx	'
config_nginx () {
  cat << 'EOF' > /usr/local/etc/nginx/nginx.conf
daemon off;
events {
  accept_mutex off;
  worker_connections 8000;
}
http {
  charset utf-8;
  charset_types
    application/javascript
    application/json
    application/rss+xml
    application/xhtml+xml
    application/xml
    text/css
    text/plain
    text/vnd.wap.wml;
  default_type application/octet-stream;
  error_log /dev/stderr;
  gzip on;
  gzip_comp_level 9;
  gzip_min_length 256;
  gzip_proxied any;
  gzip_static on;
  gzip_vary on;
  gzip_types
    application/atom+xml
    application/javascript
    application/json
    application/ld+json
    application/manifest+json
    application/rss+xml
    application/vnd.geo+json
    application/vnd.ms-fontobject
    application/x-font-ttf
    application/x-web-app-manifest+json
    application/xhtml+xml
    application/xml
    font/opentype
    image/bmp
    image/svg+xml
    image/x-icon
    text/cache-manifest
    text/css
    text/plain
    text/vcard
    text/vnd.rim.location.xloc
    text/vtt
    text/x-component
    text/x-cross-domain-policy;
  index index.html index.xhtml;
  log_format default '$host $status $body_bytes_sent "$request" "$http_referer"\n'
    '  $remote_addr "$http_user_agent"';
  map $http_upgrade $connection_upgrade {
    default upgrade;
    "" close;
  }
  proxy_http_version 1.1;
  proxy_set_header Upgrade $http_upgrade;
  proxy_set_header Connection $connection_upgrade;
  proxy_set_header Host $host;
  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  proxy_set_header X-Forwarded-Proto $scheme;
  proxy_set_header X-Real-IP $remote_addr;
  proxy_buffering off;
  proxy_redirect off;
  sendfile on;
  sendfile_max_chunk 512k;
  server_tokens off;
  resolver 8.8.8.8 8.8.4.4 [2001:4860:4860::8888] [2001:4860:4860::8844] valid=300s;
  resolver_timeout 5s;
  # https://hynek.me/articles/hardening-your-web-servers-ssl-ciphers/
  ssl_ciphers ECDH+AESGCM:DH+AESGCM:ECDH+AES256:DH+AES256:ECDH+AES128:DH+AES:RSA+AESGCM:RSA+AES:!aNULL:!MD5:!DSS:!AES128;
  # openssl dhparam -out /etc/letsencrypt/ssl-dhparam.pem 4096
  ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
  ssl_ecdh_curve secp384r1;
  ssl_prefer_server_ciphers on;
  ssl_protocols TLSv1.2;
  ssl_session_cache shared:TLS:10m;
  types {
    application/atom+xml atom;
    application/font-woff woff;
    application/font-woff2 woff2;
    application/java-archive ear jar war;
    application/javascript js;
    application/json json map topojson;
    application/ld+json jsonld;
    application/mac-binhex40 hqx;
    application/manifest+json webmanifest;
    application/msword doc;
    application/octet-stream bin deb dll dmg exe img iso msi msm msp safariextz;
    application/pdf pdf;
    application/postscript ai eps ps;
    application/rss+xml rss;
    application/rtf rtf;
    application/vnd.geo+json geojson;
    application/vnd.google-earth.kml+xml kml;
    application/vnd.google-earth.kmz kmz;
    application/vnd.ms-excel xls;
    application/vnd.ms-fontobject eot;
    application/vnd.ms-powerpoint ppt;
    application/vnd.openxmlformats-officedocument.presentationml.presentation pptx;
    application/vnd.openxmlformats-officedocument.spreadsheetml.sheet xlsx;
    application/vnd.openxmlformats-officedocument.wordprocessingml.document docx;
    application/vnd.wap.wmlc wmlc;
    application/x-7z-compressed 7z;
    application/x-bb-appworld bbaw;
    application/x-bittorrent torrent;
    application/x-chrome-extension crx;
    application/x-cocoa cco;
    application/x-font-ttf ttc ttf;
    application/x-java-archive-diff jardiff;
    application/x-java-jnlp-file jnlp;
    application/x-makeself run;
    application/x-opera-extension oex;
    application/x-perl pl pm;
    application/x-pilot pdb prc;
    application/x-rar-compressed rar;
    application/x-redhat-package-manager rpm;
    application/x-sea sea;
    application/x-shockwave-flash swf;
    application/x-stuffit sit;
    application/x-tcl tcl tk;
    application/x-web-app-manifest+json webapp;
    application/x-x509-ca-cert crt der pem;
    application/x-xpinstall xpi;
    application/xhtml+xml xhtml;
    application/xml rdf xml;
    application/xslt+xml xsl;
    application/zip zip;
    audio/midi mid midi kar;
    audio/mp4 aac f4a f4b m4a;
    audio/mpeg mp3;
    audio/ogg oga ogg opus;
    audio/x-realaudio ra;
    audio/x-wav wav;
    font/opentype otf;
    image/bmp bmp;
    image/gif gif;
    image/jpeg jpeg jpg;
    image/png png;
    image/svg+xml svg svgz;
    image/tiff tif tiff;
    image/vnd.wap.wbmp wbmp;
    image/webp webp;
    image/x-icon cur ico;
    image/x-jng jng;
    text/cache-manifest appcache;
    text/css css;
    text/html htm html shtml;
    text/mathml mml;
    text/plain txt;
    text/vcard vcard vcf;
    text/vnd.rim.location.xloc xloc;
    text/vnd.sun.j2me.app-descriptor jad;
    text/vnd.wap.wml wml;
    text/vtt vtt;
    text/x-component htc;
    video/3gpp 3gp 3gpp;
    video/mp4 f4p f4v m4v mp4;
    video/mpeg mpeg mpg;
    video/ogg ogv;
    video/quicktime mov;
    video/webm webm;
    video/x-flv flv;
    video/x-mng mng;
    video/x-ms-asf asf asx;
    video/x-ms-wmv wmv;
    video/x-msvideo avi;
  }
  include servers/*.conf;
}
worker_processes auto;
EOF

  ld="/Library/LaunchDaemons/org.nginx.nginx"

  sudo mkdir -p "$(dirname $ld)"
  sudo launchctl unload "${ld}.plist" 2> /dev/null
  sudo rm -f "${ld}.plist"

  config_defaults "$_nginx_defaults" "sudo"
  sudo plutil -convert xml1 "${ld}.plist"
  sudo launchctl load "${ld}.plist" 2> /dev/null
}

# Configure OpenSSL
# Create an intentionally invalid certificate for use with a DNS-based ad blocker, e.g. https://pi-hole.net

config_openssl () {
  _default="/etc/letsencrypt/live/default"
  test -d "$_default" || mkdir -p "$_default"

  cat << EOF > "${_default}/default.cnf"
[ req ]
default_bits = 4096
default_keyfile = ${_default}/default.key
default_md = sha256
distinguished_name = dn
encrypt_key = no
prompt = no
utf8 = yes
x509_extensions = v3_ca
[ dn ]
CN = *
[ v3_ca ]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = CA:true
EOF

  openssl req -days 1 -new -newkey rsa -x509 \
    -config "${_default}/default.cnf" \
    -out "${_default}/default.crt"

  cat << EOF > "/usr/local/etc/nginx/servers/default.conf"
server {
  server_name .$(hostname -f | cut -d. -f2-);
  listen 80;
  listen [::]:80;
  return 301 https://\$host\$request_uri;
}
server {
  listen 80 default_server;
  listen [::]:80 default_server;
  listen 443 default_server ssl http2;
  listen [::]:443 default_server ssl http2;
  ssl_certificate ${_default}/default.crt;
  ssl_certificate_key ${_default}/default.key;
  ssl_ciphers NULL;
  return 204;
}
EOF
}

# Configure System Preferences

config_sysprefs () {
  config_energy
  config_loginwindow
  config_mas
}

# Configure Energy Saver

_energy='-c	displaysleep	0
-c	sleep	0
-c	disksleep	0
-c	womp	0
-c	autorestart	0
-c	powernap	0
-u	displaysleep	0
-u	lessbright	0
-u	haltafter	0
-u	haltremain	0
-u	haltlevel	0'

config_energy () {
  printf "%s\n" "${_energy}" | \
  while IFS="$(printf '\t')" read flag setting value; do
    sudo pmset $flag ${setting} ${value}
  done
}

# Configure Login Window

_loginwindow='/Library/Preferences/com.apple.loginwindow
SHOWFULLNAME
-bool
true
'

config_loginwindow () {
  config_defaults "${_loginwindow}" "sudo"
}

# Configure App Store

_swupdate='/Library/Preferences/com.apple.commerce	AutoUpdate	-bool	true	
/Library/Preferences/com.apple.commerce	AutoUpdateRestartRequired	-bool	true	'

config_mas () {
  config_defaults "${_swupdate}" "sudo"
}

# Configure Z-Shell

config_zsh () {
  grep -q "$(which zsh)" /etc/shells ||
  print "$(which zsh)\n" | \
  sudo tee -a /etc/shells > /dev/null

  case "$SHELL" in
    ($(which zsh)) ;;
    (*)
      chsh -s "$(which zsh)"
      sudo chsh -s $(which zsh) ;;
  esac

  sudo tee -a /etc/zshenv << 'EOF' > /dev/null
#-- Exports ----------------------------------------------------
export \
  ZDOTDIR="${HOME}/.zsh" \
  MASDIR="$(getconf DARWIN_USER_CACHE_DIR)com.apple.appstore" \
  NODENV_ROOT="/usr/local/node" \
  PLENV_ROOT="/usr/local/perl" \
  PYENV_ROOT="/usr/local/python" \
  RBENV_ROOT="/usr/local/ruby" \
  EDITOR="nano" \
  VISUAL="vi" \
  PAGER="less" \
  LANG="en_US.UTF-8" \
  LESS="-egiMQRS -x2 -z-2" \
  LESSHISTFILE="/dev/null" \
  HISTSIZE=50000 \
  SAVEHIST=50000 \
  KEYTIMEOUT=1
test -d "$ZDOTDIR" || \
  mkdir -p "$ZDOTDIR"
test -f "${ZDOTDIR}/.zshrc" || \
  touch "${ZDOTDIR}/.zshrc"
# Ensure path arrays do not contain duplicates.
typeset -gU cdpath fpath mailpath path
EOF
  sudo chmod +x "/etc/zshenv"
  . "/etc/zshenv"

  sudo tee /etc/zshrc << 'EOF' > /dev/null
#-- Exports ----------------------------------------------------
export \
  HISTFILE="${ZDOTDIR:-$HOME}/.zhistory"
#-- Changing Directories ---------------------------------------
setopt \
  autocd \
  autopushd \
  cdablevars \
  chasedots \
  chaselinks \
  NO_posixcd \
  pushdignoredups \
  no_pushdminus \
  pushdsilent \
  pushdtohome
#-- Completion -------------------------------------------------
setopt \
  ALWAYSLASTPROMPT \
  no_alwaystoend \
  AUTOLIST \
  AUTOMENU \
  autonamedirs \
  AUTOPARAMKEYS \
  AUTOPARAMSLASH \
  AUTOREMOVESLASH \
  no_bashautolist \
  no_completealiases \
  completeinword \
  no_globcomplete \
  HASHLISTALL \
  LISTAMBIGUOUS \
  no_LISTBEEP \
  no_listpacked \
  no_listrowsfirst \
  LISTTYPES \
  no_menucomplete \
  no_recexact
#-- Expansion and Globbing -------------------------------------
setopt \
  BADPATTERN \
  BAREGLOBQUAL \
  braceccl \
  CASEGLOB \
  CASEMATCH \
  NO_cshnullglob \
  EQUALS \
  extendedglob \
  no_forcefloat \
  GLOB \
  NO_globassign \
  no_globdots \
  no_globstarshort \
  NO_globsubst \
  no_histsubstpattern \
  NO_ignorebraces \
  no_ignoreclosebraces \
  NO_kshglob \
  no_magicequalsubst \
  no_markdirs \
  MULTIBYTE \
  NOMATCH \
  no_nullglob \
  no_numericglobsort \
  no_rcexpandparam \
  no_rematchpcre \
  NO_shglob \
  UNSET \
  no_warncreateglobal \
  no_warnnestedvar
#-- History ----------------------------------------------------
setopt \
  APPENDHISTORY \
  BANGHIST \
  extendedhistory \
  no_histallowclobber \
  no_HISTBEEP \
  histexpiredupsfirst \
  no_histfcntllock \
  histfindnodups \
  histignorealldups \
  histignoredups \
  histignorespace \
  histlexwords \
  no_histnofunctions \
  no_histnostore \
  histreduceblanks \
  HISTSAVEBYCOPY \
  histsavenodups \
  histverify \
  incappendhistory \
  incappendhistorytime \
  sharehistory
#-- Initialisation ---------------------------------------------
setopt \
  no_allexport \
  GLOBALEXPORT \
  GLOBALRCS \
  RCS
#-- Input/Output -----------------------------------------------
setopt \
  ALIASES \
  no_CLOBBER \
  no_correct \
  no_correctall \
  dvorak \
  no_FLOWCONTROL \
  no_ignoreeof \
  NO_interactivecomments \
  HASHCMDS \
  HASHDIRS \
  no_hashexecutablesonly \
  no_mailwarning \
  pathdirs \
  NO_pathscript \
  no_printeightbit \
  no_printexitvalue \
  rcquotes \
  NO_rmstarsilent \
  no_rmstarwait \
  SHORTLOOPS \
  no_sunkeyboardhack
#-- Job Control ------------------------------------------------
setopt \
  no_autocontinue \
  autoresume \
  no_BGNICE \
  CHECKJOBS \
  no_HUP \
  longlistjobs \
  MONITOR \
  NOTIFY \
  NO_posixjobs
#-- Prompting --------------------------------------------------
setopt \
  NO_promptbang \
  PROMPTCR \
  PROMPTSP \
  PROMPTPERCENT \
  promptsubst \
  transientrprompt
#-- Scripts and Functions --------------------------------------
setopt \
  NO_aliasfuncdef \
  no_cbases \
  no_cprecedences \
  DEBUGBEFORECMD \
  no_errexit \
  no_errreturn \
  EVALLINENO \
  EXEC \
  FUNCTIONARGZERO \
  no_localloops \
  NO_localoptions \
  no_localpatterns \
  NO_localtraps \
  MULTIFUNCDEF \
  MULTIOS \
  NO_octalzeroes \
  no_pipefail \
  no_sourcetrace \
  no_typesetsilent \
  no_verbose \
  no_xtrace
#-- Shell Emulation --------------------------------------------
setopt \
  NO_appendcreate \
  no_bashrematch \
  NO_bsdecho \
  no_continueonerror \
  NO_cshjunkiehistory \
  NO_cshjunkieloops \
  NO_cshjunkiequotes \
  NO_cshnullcmd \
  NO_ksharrays \
  NO_kshautoload \
  NO_kshoptionprint \
  no_kshtypeset \
  no_kshzerosubscript \
  NO_posixaliases \
  no_posixargzero \
  NO_posixbuiltins \
  NO_posixidentifiers \
  NO_posixstrings \
  NO_posixtraps \
  NO_shfileexpansion \
  NO_shnullcmd \
  NO_shoptionletters \
  NO_shwordsplit \
  no_trapsasync
#-- Zle --------------------------------------------------------
setopt \
  no_BEEP \
  combiningchars \
  no_overstrike \
  NO_singlelinezle
#-- Aliases ----------------------------------------------------
alias \
  ll="/bin/ls -aFGHhlOw"
#-- Functions --------------------------------------------------
autoload -Uz \
  add-zsh-hook \
  compaudit \
  compinit
compaudit 2> /dev/null | \
  xargs -L 1 chmod go-w 2> /dev/null
compinit -u
which nodenv > /dev/null && \
  eval "$(nodenv init - zsh)"
which plenv > /dev/null && \
  eval "$(plenv init - zsh)"
which pyenv > /dev/null && \
  eval "$(pyenv init - zsh)"
which rbenv > /dev/null && \
  eval "$(rbenv init - zsh)"
sf () {
  SetFile -P -d "$1 12:00:00" -m "$1 12:00:00" $argv[2,$]
}
ssh-add -A 2> /dev/null
#-- zsh-syntax-highlighting ------------------------------------
. "$(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
#-- zsh-history-substring-search -------------------------------
. "$(brew --prefix)/share/zsh-history-substring-search/zsh-history-substring-search.zsh"
HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND="fg=default,underline" && \
  export HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND
HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_NOT_FOUND="fg=red,underline" && \
  export HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_NOT_FOUND
#-- Zle --------------------------------------------------------
zmodload zsh/zle
bindkey -d
bindkey -v
for k in "vicmd" "viins"; do
  bindkey -M $k '\C-A' beginning-of-line
  bindkey -M $k '\C-E' end-of-line
  bindkey -M $k '\C-U' kill-whole-line
  bindkey -M $k '\e[3~' delete-char
  bindkey -M $k '\e[A' history-substring-search-up
  bindkey -M $k '\e[B' history-substring-search-down
  bindkey -M $k '\x7f' backward-delete-char
done
for f in \
  "zle-keymap-select" \
  "zle-line-finish" \
  "zle-line-init"
do
  eval "$f () {
    case \$TERM_PROGRAM in
      ('Apple_Terminal')
        test \$KEYMAP = 'vicmd' && \
          printf '%b' '\e[4 q' || \
          printf '%b' '\e[6 q' ;;
      ('iTerm.app')
        test \$KEYMAP = 'vicmd' && \
          printf '%b' '\e]Plf27f7f\e\x5c\e[4 q' || \
          printf '%b' '\e]Pl99cc99\e\x5c\e[6 q' ;;
    esac
  }"
  zle -N $f
done
#-- prompt_ptb_setup -------------------------------------------
prompt_ptb_setup () {
  I="$(printf '%b' '%{\e[3m%}')"
  i="$(printf '%b' '%{\e[0m%}')"
  PROMPT="%F{004}$I%d$i %(!.%F{001}.%F{002})%n %B❯%b%f " && \
  export PROMPT
}
prompt_ptb_setup
prompt_ptb_precmd () {
  if test "$(uname -s)" = "Darwin"; then
    print -Pn "\e]7;file://%M\${PWD// /%%20}\a"
    print -Pn "\e]2;%n@%m\a"
    print -Pn "\e]1;%~\a"
  fi
  test -n "$(git rev-parse --git-dir 2> /dev/null)" && \
  RPROMPT="%F{000}$(git rev-parse --abbrev-ref HEAD 2> /dev/null)%f" && \
  export RPROMPT
}
add-zsh-hook precmd \
  prompt_ptb_precmd
EOF
  sudo chmod +x "/etc/zshrc"
  . "/etc/zshrc"
}

# Configure New Account

config_new_account () {
  e="$(ask 'New macOS Account: Email Address?' 'OK' '')"
  curl --output "/Library/User Pictures/${e}.jpg" --silent \
    "https://www.gravatar.com/avatar/$(md5 -qs ${e}).jpg?s=512"

  g="$(curl --location --silent \
    "https://api.github.com/search/users?q=${e}" | \
    sed -n 's/^.*"url": "\(.*\)".*/\1/p')"
  g="$(curl --location --silent ${g})"

  n="$(printf ${g} | sed -n 's/^.*"name": "\(.*\)".*/\1/p')"
  n="$(ask 'New macOS Account: Real Name?' 'OK' ${n})"

  u="$(printf ${g} | sed -n 's/^.*"login": "\(.*\)".*/\1/p')"
  u="$(ask 'New macOS Account: User Name?' 'OK' ${u})"

  sudo defaults write \
    "/System/Library/User Template/Non_localized/Library/Preferences/.GlobalPreferences.plist" \
    "com.apple.swipescrolldirection" -bool false

  sudo sysadminctl -admin -addUser "${u}" -fullName "${n}" -password - \
    -shell "$(which zsh)" -picture "/Library/User Pictures/${e}.jpg"
}

# Configure Guest Users

config_guest () {
  sudo sysadminctl -guestAccount off
}

# Reinstate =sudo= Password

config_rm_sudoers () {
  sudo -- sh -c \
    "rm -f /etc/sudoers.d/wheel; dscl /Local/Default -delete /Groups/wheel GroupMembership $(whoami)"

  /usr/bin/read -n 1 -p "Press any key to continue.
" -s
  if run "Log Out Then Log Back In?" "Cancel" "Log Out"; then
    osascript -e 'tell app "loginwindow" to «event aevtrlgo»'
  fi
}

# Define Function =custom=

custom () {
  custom_githome
  custom_atom
  custom_autoping
  custom_dropbox
  custom_duti
  custom_emacs
  custom_finder
  custom_getmail
  custom_git
  custom_gnupg
  custom_istatmenus
  custom_meteorologist
  custom_moom
  custom_mp4_automator
  custom_nvalt
  custom_nzbget
  custom_safari
  custom_sieve
  custom_sonarr
  custom_ssh
  custom_sysprefs
  custom_terminal
  custom_vim
  custom_vlc

  which personalize_all
}

# Customize Home

custom_githome () {
  git -C "${HOME}" init

  test -f "${CACHES}/dbx/.zshenv" && \
    mkdir -p "${ZDOTDIR:-$HOME}" && \
    cp "${CACHES}/dbx/.zshenv" "${ZDOTDIR:-$HOME}" && \
    . "${ZDOTDIR:-$HOME}/.zshenv"

  a=$(ask "Existing Git Home Repository Path or URL" "Add Remote" "")
  if test -n "${a}"; then
    git -C "${HOME}" remote add origin "${a}"
    git -C "${HOME}" fetch origin master
  fi

  if run "Encrypt and commit changes to Git and push to GitHub, automatically?" "No" "Add AutoKeep"; then
    curl --location --silent \
      "https://github.com/ptb/autokeep/raw/master/autokeep.command" | \
      . /dev/stdin 0

    autokeep_remote
    autokeep_push
    autokeep_gitignore
    autokeep_post_commit
    autokeep_launchagent
    autokeep_crypt

    git reset --hard
    git checkout -f -b master FETCH_HEAD
  fi

  chmod -R go= "${HOME}" > /dev/null 2>&1
}

# Customize Default UTIs

_duti='com.apple.DiskImageMounter	com.apple.disk-image	all
com.apple.DiskImageMounter	public.disk-image	all
com.apple.DiskImageMounter	public.iso-image	all
com.apple.QuickTimePlayerX	com.apple.coreaudio-format	all
com.apple.QuickTimePlayerX	com.apple.quicktime-movie	all
com.apple.QuickTimePlayerX	com.microsoft.waveform-audio	all
com.apple.QuickTimePlayerX	public.aifc-audio	all
com.apple.QuickTimePlayerX	public.aiff-audio	all
com.apple.QuickTimePlayerX	public.audio	all
com.apple.QuickTimePlayerX	public.mp3	all
com.apple.Safari	com.compuserve.gif	all
com.apple.Terminal	com.apple.terminal.shell-script	all
com.apple.iTunes	com.apple.iTunes.audible	all
com.apple.iTunes	com.apple.iTunes.ipg	all
com.apple.iTunes	com.apple.iTunes.ipsw	all
com.apple.iTunes	com.apple.iTunes.ite	all
com.apple.iTunes	com.apple.iTunes.itlp	all
com.apple.iTunes	com.apple.iTunes.itms	all
com.apple.iTunes	com.apple.iTunes.podcast	all
com.apple.iTunes	com.apple.m4a-audio	all
com.apple.iTunes	com.apple.mpeg-4-ringtone	all
com.apple.iTunes	com.apple.protected-mpeg-4-audio	all
com.apple.iTunes	com.apple.protected-mpeg-4-video	all
com.apple.iTunes	com.audible.aa-audio	all
com.apple.iTunes	public.mpeg-4-audio	all
com.apple.installer	com.apple.installer-package-archive	all
com.github.atom	com.apple.binary-property-list	editor
com.github.atom	com.apple.crashreport	editor
com.github.atom	com.apple.dt.document.ascii-property-list	editor
com.github.atom	com.apple.dt.document.script-suite-property-list	editor
com.github.atom	com.apple.dt.document.script-terminology-property-list	editor
com.github.atom	com.apple.log	editor
com.github.atom	com.apple.property-list	editor
com.github.atom	com.apple.rez-source	editor
com.github.atom	com.apple.symbol-export	editor
com.github.atom	com.apple.xcode.ada-source	editor
com.github.atom	com.apple.xcode.bash-script	editor
com.github.atom	com.apple.xcode.configsettings	editor
com.github.atom	com.apple.xcode.csh-script	editor
com.github.atom	com.apple.xcode.fortran-source	editor
com.github.atom	com.apple.xcode.ksh-script	editor
com.github.atom	com.apple.xcode.lex-source	editor
com.github.atom	com.apple.xcode.make-script	editor
com.github.atom	com.apple.xcode.mig-source	editor
com.github.atom	com.apple.xcode.pascal-source	editor
com.github.atom	com.apple.xcode.strings-text	editor
com.github.atom	com.apple.xcode.tcsh-script	editor
com.github.atom	com.apple.xcode.yacc-source	editor
com.github.atom	com.apple.xcode.zsh-script	editor
com.github.atom	com.apple.xml-property-list	editor
com.github.atom	com.barebones.bbedit.actionscript-source	editor
com.github.atom	com.barebones.bbedit.erb-source	editor
com.github.atom	com.barebones.bbedit.ini-configuration	editor
com.github.atom	com.barebones.bbedit.javascript-source	editor
com.github.atom	com.barebones.bbedit.json-source	editor
com.github.atom	com.barebones.bbedit.jsp-source	editor
com.github.atom	com.barebones.bbedit.lasso-source	editor
com.github.atom	com.barebones.bbedit.lua-source	editor
com.github.atom	com.barebones.bbedit.setext-source	editor
com.github.atom	com.barebones.bbedit.sql-source	editor
com.github.atom	com.barebones.bbedit.tcl-source	editor
com.github.atom	com.barebones.bbedit.tex-source	editor
com.github.atom	com.barebones.bbedit.textile-source	editor
com.github.atom	com.barebones.bbedit.vbscript-source	editor
com.github.atom	com.barebones.bbedit.vectorscript-source	editor
com.github.atom	com.barebones.bbedit.verilog-hdl-source	editor
com.github.atom	com.barebones.bbedit.vhdl-source	editor
com.github.atom	com.barebones.bbedit.yaml-source	editor
com.github.atom	com.netscape.javascript-source	editor
com.github.atom	com.sun.java-source	editor
com.github.atom	dyn.ah62d4rv4ge80255drq	all
com.github.atom	dyn.ah62d4rv4ge80g55gq3w0n	all
com.github.atom	dyn.ah62d4rv4ge80g55sq2	all
com.github.atom	dyn.ah62d4rv4ge80y2xzrf0gk3pw	all
com.github.atom	dyn.ah62d4rv4ge81e3dtqq	all
com.github.atom	dyn.ah62d4rv4ge81e7k	all
com.github.atom	dyn.ah62d4rv4ge81g25xsq	all
com.github.atom	dyn.ah62d4rv4ge81g2pxsq	all
com.github.atom	net.daringfireball.markdown	editor
com.github.atom	public.assembly-source	editor
com.github.atom	public.c-header	editor
com.github.atom	public.c-plus-plus-source	editor
com.github.atom	public.c-source	editor
com.github.atom	public.csh-script	editor
com.github.atom	public.json	editor
com.github.atom	public.lex-source	editor
com.github.atom	public.log	editor
com.github.atom	public.mig-source	editor
com.github.atom	public.nasm-assembly-source	editor
com.github.atom	public.objective-c-plus-plus-source	editor
com.github.atom	public.objective-c-source	editor
com.github.atom	public.patch-file	editor
com.github.atom	public.perl-script	editor
com.github.atom	public.php-script	editor
com.github.atom	public.plain-text	editor
com.github.atom	public.precompiled-c-header	editor
com.github.atom	public.precompiled-c-plus-plus-header	editor
com.github.atom	public.python-script	editor
com.github.atom	public.ruby-script	editor
com.github.atom	public.script	editor
com.github.atom	public.shell-script	editor
com.github.atom	public.source-code	editor
com.github.atom	public.text	editor
com.github.atom	public.utf16-external-plain-text	editor
com.github.atom	public.utf16-plain-text	editor
com.github.atom	public.utf8-plain-text	editor
com.github.atom	public.xml	editor
com.kodlian.Icon-Slate	com.apple.icns	all
com.kodlian.Icon-Slate	com.microsoft.ico	all
com.microsoft.Word	public.rtf	all
com.panayotis.jubler	dyn.ah62d4rv4ge81g6xy	all
com.sketchup.SketchUp.2017	com.sketchup.skp	all
com.VortexApps.NZBVortex3	dyn.ah62d4rv4ge8068xc	all
com.vmware.fusion	com.microsoft.windows-executable	all
cx.c3.theunarchiver	com.alcohol-soft.mdf-image	all
cx.c3.theunarchiver	com.allume.stuffit-archive	all
cx.c3.theunarchiver	com.altools.alz-archive	all
cx.c3.theunarchiver	com.amiga.adf-archive	all
cx.c3.theunarchiver	com.amiga.adz-archive	all
cx.c3.theunarchiver	com.apple.applesingle-archive	all
cx.c3.theunarchiver	com.apple.binhex-archive	all
cx.c3.theunarchiver	com.apple.bom-compressed-cpio	all
cx.c3.theunarchiver	com.apple.itunes.ipa	all
cx.c3.theunarchiver	com.apple.macbinary-archive	all
cx.c3.theunarchiver	com.apple.self-extracting-archive	all
cx.c3.theunarchiver	com.apple.xar-archive	all
cx.c3.theunarchiver	com.apple.xip-archive	all
cx.c3.theunarchiver	com.cyclos.cpt-archive	all
cx.c3.theunarchiver	com.microsoft.cab-archive	all
cx.c3.theunarchiver	com.microsoft.msi-installer	all
cx.c3.theunarchiver	com.nero.nrg-image	all
cx.c3.theunarchiver	com.network172.pit-archive	all
cx.c3.theunarchiver	com.nowsoftware.now-archive	all
cx.c3.theunarchiver	com.nscripter.nsa-archive	all
cx.c3.theunarchiver	com.padus.cdi-image	all
cx.c3.theunarchiver	com.pkware.zip-archive	all
cx.c3.theunarchiver	com.rarlab.rar-archive	all
cx.c3.theunarchiver	com.redhat.rpm-archive	all
cx.c3.theunarchiver	com.stuffit.archive.sit	all
cx.c3.theunarchiver	com.stuffit.archive.sitx	all
cx.c3.theunarchiver	com.sun.java-archive	all
cx.c3.theunarchiver	com.symantec.dd-archive	all
cx.c3.theunarchiver	com.winace.ace-archive	all
cx.c3.theunarchiver	com.winzip.zipx-archive	all
cx.c3.theunarchiver	cx.c3.arc-archive	all
cx.c3.theunarchiver	cx.c3.arj-archive	all
cx.c3.theunarchiver	cx.c3.dcs-archive	all
cx.c3.theunarchiver	cx.c3.dms-archive	all
cx.c3.theunarchiver	cx.c3.ha-archive	all
cx.c3.theunarchiver	cx.c3.lbr-archive	all
cx.c3.theunarchiver	cx.c3.lha-archive	all
cx.c3.theunarchiver	cx.c3.lhf-archive	all
cx.c3.theunarchiver	cx.c3.lzx-archive	all
cx.c3.theunarchiver	cx.c3.packdev-archive	all
cx.c3.theunarchiver	cx.c3.pax-archive	all
cx.c3.theunarchiver	cx.c3.pma-archive	all
cx.c3.theunarchiver	cx.c3.pp-archive	all
cx.c3.theunarchiver	cx.c3.xmash-archive	all
cx.c3.theunarchiver	cx.c3.zoo-archive	all
cx.c3.theunarchiver	cx.c3.zoom-archive	all
cx.c3.theunarchiver	org.7-zip.7-zip-archive	all
cx.c3.theunarchiver	org.archive.warc-archive	all
cx.c3.theunarchiver	org.debian.deb-archive	all
cx.c3.theunarchiver	org.gnu.gnu-tar-archive	all
cx.c3.theunarchiver	org.gnu.gnu-zip-archive	all
cx.c3.theunarchiver	org.gnu.gnu-zip-tar-archive	all
cx.c3.theunarchiver	org.tukaani.lzma-archive	all
cx.c3.theunarchiver	org.tukaani.xz-archive	all
cx.c3.theunarchiver	public.bzip2-archive	all
cx.c3.theunarchiver	public.cpio-archive	all
cx.c3.theunarchiver	public.tar-archive	all
cx.c3.theunarchiver	public.tar-bzip2-archive	all
cx.c3.theunarchiver	public.z-archive	all
cx.c3.theunarchiver	public.zip-archive	all
cx.c3.theunarchiver	public.zip-archive.first-part	all
org.gnu.Emacs	dyn.ah62d4rv4ge8086xh	all
org.inkscape.Inkscape	public.svg-image	editor
org.videolan.vlc	com.apple.m4v-video	all
org.videolan.vlc	com.microsoft.windows-media-wmv	all
org.videolan.vlc	org.videolan.3gp	all
org.videolan.vlc	org.videolan.aac	all
org.videolan.vlc	org.videolan.ac3	all
org.videolan.vlc	org.videolan.aiff	all
org.videolan.vlc	org.videolan.amr	all
org.videolan.vlc	org.videolan.aob	all
org.videolan.vlc	org.videolan.ape	all
org.videolan.vlc	org.videolan.asf	all
org.videolan.vlc	org.videolan.avi	all
org.videolan.vlc	org.videolan.axa	all
org.videolan.vlc	org.videolan.axv	all
org.videolan.vlc	org.videolan.divx	all
org.videolan.vlc	org.videolan.dts	all
org.videolan.vlc	org.videolan.dv	all
org.videolan.vlc	org.videolan.flac	all
org.videolan.vlc	org.videolan.flash	all
org.videolan.vlc	org.videolan.gxf	all
org.videolan.vlc	org.videolan.it	all
org.videolan.vlc	org.videolan.mid	all
org.videolan.vlc	org.videolan.mka	all
org.videolan.vlc	org.videolan.mkv	all
org.videolan.vlc	org.videolan.mlp	all
org.videolan.vlc	org.videolan.mod	all
org.videolan.vlc	org.videolan.mpc	all
org.videolan.vlc	org.videolan.mpeg-audio	all
org.videolan.vlc	org.videolan.mpeg-stream	all
org.videolan.vlc	org.videolan.mpeg-video	all
org.videolan.vlc	org.videolan.mxf	all
org.videolan.vlc	org.videolan.nsv	all
org.videolan.vlc	org.videolan.nuv	all
org.videolan.vlc	org.videolan.ogg-audio	all
org.videolan.vlc	org.videolan.ogg-video	all
org.videolan.vlc	org.videolan.oma	all
org.videolan.vlc	org.videolan.opus	all
org.videolan.vlc	org.videolan.quicktime	all
org.videolan.vlc	org.videolan.realmedia	all
org.videolan.vlc	org.videolan.rec	all
org.videolan.vlc	org.videolan.rmi	all
org.videolan.vlc	org.videolan.s3m	all
org.videolan.vlc	org.videolan.spx	all
org.videolan.vlc	org.videolan.tod	all
org.videolan.vlc	org.videolan.tta	all
org.videolan.vlc	org.videolan.vob	all
org.videolan.vlc	org.videolan.voc	all
org.videolan.vlc	org.videolan.vqf	all
org.videolan.vlc	org.videolan.vro	all
org.videolan.vlc	org.videolan.wav	all
org.videolan.vlc	org.videolan.webm	all
org.videolan.vlc	org.videolan.wma	all
org.videolan.vlc	org.videolan.wmv	all
org.videolan.vlc	org.videolan.wtv	all
org.videolan.vlc	org.videolan.wv	all
org.videolan.vlc	org.videolan.xa	all
org.videolan.vlc	org.videolan.xesc	all
org.videolan.vlc	org.videolan.xm	all
org.videolan.vlc	public.ac3-audio	all
org.videolan.vlc	public.audiovisual-content	all
org.videolan.vlc	public.avi	all
org.videolan.vlc	public.movie	all
org.videolan.vlc	public.mpeg	all
org.videolan.vlc	public.mpeg-2-video	all
org.videolan.vlc	public.mpeg-4	all'
custom_duti () {
  if test -x "/usr/local/bin/duti"; then
    test -f "${HOME}/Library/Preferences/org.duti.plist" && \
      rm "${HOME}/Library/Preferences/org.duti.plist"

    printf "%s\n" "${_duti}" | \
    while IFS="$(printf '\t')" read id uti role; do
      defaults write org.duti DUTISettings -array-add \
        "{
          DUTIBundleIdentifier = '$a';
          DUTIUniformTypeIdentifier = '$b';
          DUTIRole = '$c';
        }"
    done

    duti "${HOME}/Library/Preferences/org.duti.plist" 2> /dev/null
  fi
}

# Customize Finder

_finder='com.apple.finder	ShowHardDrivesOnDesktop	-bool	false	
com.apple.finder	ShowExternalHardDrivesOnDesktop	-bool	false	
com.apple.finder	ShowRemovableMediaOnDesktop	-bool	false	
com.apple.finder	ShowMountedServersOnDesktop	-bool	false	
com.apple.finder	NewWindowTarget	-string	PfLo	
com.apple.finder	NewWindowTargetPath	-string	file://${HOME}/	
-globalDomain	AppleShowAllExtensions	-bool	true	
com.apple.finder	FXEnableExtensionChangeWarning	-bool	false	
com.apple.finder	FXEnableRemoveFromICloudDriveWarning	-bool	true	
com.apple.finder	WarnOnEmptyTrash	-bool	false	
com.apple.finder	ShowPathbar	-bool	true	
com.apple.finder	ShowStatusBar	-bool	true	'

custom_finder () {
  config_defaults "${_finder}"
  defaults write "com.apple.finder" "NSToolbar Configuration Browser" \
    '{
      "TB Display Mode" = 2;
      "TB Item Identifiers" = (
        "com.apple.finder.BACK",
        "com.apple.finder.PATH",
        "com.apple.finder.SWCH",
        "com.apple.finder.ARNG",
        "NSToolbarFlexibleSpaceItem",
        "com.apple.finder.SRCH",
        "com.apple.finder.ACTN"
      );
    }'
}

# Customize getmail

_getmail_ini='destination	ignore_stderr	true
destination	type	MDA_external
options	delete	true
options	delivered_to	false
options	read_all	false
options	received	false
options	verbose	0
retriever	mailboxes	("[Gmail]/All Mail",)
retriever	move_on_delete	[Gmail]/Trash
retriever	port	993
retriever	server	imap.gmail.com
retriever	type	SimpleIMAPSSLRetriever'
_getmail_plist='add	:KeepAlive	bool	true
add	:ProcessType	string	Background
add	:ProgramArguments	array	
add	:ProgramArguments:0	string	/usr/local/bin/getmail
add	:ProgramArguments:1	string	--idle
add	:ProgramArguments:2	string	[Gmail]/All Mail
add	:ProgramArguments:3	string	--rcfile
add	:RunAtLoad	bool	true
add	:StandardOutPath	string	getmail.log
add	:StandardErrorPath	string	getmail.err'
custom_getmail () {
  test -d "${HOME}/.getmail" || \
    mkdir -m go= "${HOME}/.getmail"

  while true; do
    e=$(ask2 "To configure getmail, enter your email address." "Configure Getmail" "No More Addresses" "Create Configuration" "$(whoami)@$(hostname -f | cut -d. -f2-)" "false")
    test -n "$e" || break

    security find-internet-password -a "$e" -D "getmail password" > /dev/null || \
    p=$(ask2 "Enter your password for $e." "Configure Getmail" "Cancel" "Set Password" "" "true") && \
    security add-internet-password -a "$e" -s "imap.gmail.com" -r "imap" \
      -l "$e" -D "getmail password" -P 993 -w "$p"

    if which crudini > /dev/null; then
      gm="${HOME}/.getmail/${e}"
      printf "%s\n" "${_getmail_ini}" | \
      while IFS="$(printf '\t')" read section key value; do
        crudini --set "$gm" "$section" "$key" "$value"
      done
      crudini --set "$gm" "destination" "arguments" "('-c','/usr/local/etc/dovecot/dovecot.conf','-d','$(whoami)')"
      crudini --set "$gm" "destination" "path" "$(find '/usr/local/Cellar/dovecot' -name 'dovecot-lda' -print -quit)"
      crudini --set "$gm" "retriever" "username" "$e"
    fi

    la="${HOME}/Library/LaunchAgents/ca.pyropus.getmail.${e}"

    test -d "$(dirname $la)" || \
      mkdir -p "$(dirname $la)"
    launchctl unload "${la}.plist" 2> /dev/null
    rm -f "${la}.plist"

    config_plist "$_getmail_plist" "${la}.plist"
    config_defaults "$(printf "${la}\tLabel\t-string\tca.pyropus.getmail.${e}\t")"
    config_defaults "$(printf "${la}\tProgramArguments\t-array-add\t${e}\t")"
    config_defaults "$(printf "${la}\tWorkingDirectory\t-string\t${HOME}/.getmail\t")"

    plutil -convert xml1 "${la}.plist"
    launchctl load "${la}.plist" 2> /dev/null
  done
}

# Customize Git

custom_git () {
  if ! test -e "${HOME}/.gitconfig"; then
    true
  fi
}

# Customize iStat Menus

_istatmenus='com.bjango.istatmenus5.extras	MenubarSkinColor	-int	8	
com.bjango.istatmenus5.extras	MenubarTheme	-int	0	
com.bjango.istatmenus5.extras	DropdownTheme	-int	1	
com.bjango.istatmenus5.extras	CPU_MenubarMode	-string	100,2,0	
com.bjango.istatmenus5.extras	CPU_MenubarTextSize	-int	14	
com.bjango.istatmenus5.extras	CPU_MenubarGraphShowBackground	-int	0	
com.bjango.istatmenus5.extras	CPU_MenubarGraphWidth	-int	32	
com.bjango.istatmenus5.extras	CPU_MenubarGraphBreakdowns	-int	0	
com.bjango.istatmenus5.extras	CPU_MenubarGraphCustomColors	-int	0	
com.bjango.istatmenus5.extras	CPU_MenubarGraphOverall	-string	0.40 0.60 0.40 1.00	
com.bjango.istatmenus5.extras	CPU_MenubarCombineCores	-int	1	
com.bjango.istatmenus5.extras	CPU_MenubarGroupItems	-int	0	
com.bjango.istatmenus5.extras	CPU_MenubarSingleHistoryGraph	-int	0	
com.bjango.istatmenus5.extras	CPU_CombineLogicalCores	-int	1	
com.bjango.istatmenus5.extras	CPU_AppFormat	-int	0	
com.bjango.istatmenus5.extras	Memory_MenubarMode	-string	100,2,6	
com.bjango.istatmenus5.extras	Memory_MenubarPercentageSize	-int	14	
com.bjango.istatmenus5.extras	Memory_MenubarGraphBreakdowns	-int	1	
com.bjango.istatmenus5.extras	Memory_MenubarGraphCustomColors	-int	0	
com.bjango.istatmenus5.extras	Memory_MenubarGraphOverall	-string	0.40 0.60 0.40 1.00	
com.bjango.istatmenus5.extras	Memory_MenubarGraphWired	-string	0.40 0.60 0.40 1.00	
com.bjango.istatmenus5.extras	Memory_MenubarGraphActive	-string	0.47 0.67 0.47 1.00	
com.bjango.istatmenus5.extras	Memory_MenubarGraphCompressed	-string	0.53 0.73 0.53 1.00	
com.bjango.istatmenus5.extras	Memory_MenubarGraphInactive	-string	0.60 0.80 0.60 1.00	
com.bjango.istatmenus5.extras	Memory_IgnoreInactive	-int	0	
com.bjango.istatmenus5.extras	Memory_AppFormat	-int	0	
com.bjango.istatmenus5.extras	Memory_DisplayFormat	-int	1	
com.bjango.istatmenus5.extras	Disks_MenubarMode	-string	100,9,8	
com.bjango.istatmenus5.extras	Disks_MenubarGroupItems	-int	1	
com.bjango.istatmenus5.extras	Disks_MenubarRWShowLabel	-int	1	
com.bjango.istatmenus5.extras	Disks_MenubarRWBold	-int	0	
com.bjango.istatmenus5.extras	Disks_MenubarGraphActivityWidth	-int	32	
com.bjango.istatmenus5.extras	Disks_MenubarGraphActivityShowBackground	-int	0	
com.bjango.istatmenus5.extras	Disks_MenubarGraphActivityCustomColors	-int	0	
com.bjango.istatmenus5.extras	Disks_MenubarGraphActivityRead	-string	0.60 0.80 0.60 1.00	
com.bjango.istatmenus5.extras	Disks_MenubarGraphActivityWrite	-string	0.40 0.60 0.40 1.00	
com.bjango.istatmenus5.extras	Disks_SeperateFusion	-int	1	
com.bjango.istatmenus5.extras	Network_MenubarMode	-string	4,0,1	
com.bjango.istatmenus5.extras	Network_TextUploadColor-Dark	-string	1.00 1.00 1.00 1.00	
com.bjango.istatmenus5.extras	Network_TextDownloadColor-Dark	-string	1.00 1.00 1.00 1.00	
com.bjango.istatmenus5.extras	Network_GraphWidth	-int	32	
com.bjango.istatmenus5.extras	Network_GraphShowBackground	-int	0	
com.bjango.istatmenus5.extras	Network_GraphCustomColors	-int	0	
com.bjango.istatmenus5.extras	Network_GraphUpload	-string	0.60 0.80 0.60 1.00	
com.bjango.istatmenus5.extras	Network_GraphDownload	-string	0.40 0.60 0.40 1.00	
com.bjango.istatmenus5.extras	Network_GraphMode	-int	1	
com.bjango.istatmenus5.extras	Battery_MenubarMode	-string	5,0	
com.bjango.istatmenus5.extras	Battery_ColorGraphCustomColors	-int	1	
com.bjango.istatmenus5.extras	Battery_ColorGraphCharged	-string	0.40 0.60 0.40 1.00	
com.bjango.istatmenus5.extras	Battery_ColorGraphCharging	-string	0.60 0.80 0.60 1.00	
com.bjango.istatmenus5.extras	Battery_ColorGraphDraining	-string	1.00 0.60 0.60 1.00	
com.bjango.istatmenus5.extras	Battery_ColorGraphLow	-string	1.00 0.20 0.20 1.00	
com.bjango.istatmenus5.extras	Battery_PercentageSize	-int	14	
com.bjango.istatmenus5.extras	Battery_MenubarCustomizeStates	-int	0	
com.bjango.istatmenus5.extras	Battery_MenubarHideBluetooth	-int	1	
com.bjango.istatmenus5.extras	Time_MenubarFormat	-array-add	EE	
com.bjango.istatmenus5.extras	Time_MenubarFormat	-array-add	\\040	
com.bjango.istatmenus5.extras	Time_MenubarFormat	-array-add	MMM	
com.bjango.istatmenus5.extras	Time_MenubarFormat	-array-add	\\040	
com.bjango.istatmenus5.extras	Time_MenubarFormat	-array-add	d	
com.bjango.istatmenus5.extras	Time_MenubarFormat	-array-add	\\040	
com.bjango.istatmenus5.extras	Time_MenubarFormat	-array-add	h	
com.bjango.istatmenus5.extras	Time_MenubarFormat	-array-add	:	
com.bjango.istatmenus5.extras	Time_MenubarFormat	-array-add	mm	
com.bjango.istatmenus5.extras	Time_MenubarFormat	-array-add	:	
com.bjango.istatmenus5.extras	Time_MenubarFormat	-array-add	ss	
com.bjango.istatmenus5.extras	Time_MenubarFormat	-array-add	\\040	
com.bjango.istatmenus5.extras	Time_MenubarFormat	-array-add	a	
com.bjango.istatmenus5.extras	Time_DropdownFormat	-array-add	EE	
com.bjango.istatmenus5.extras	Time_DropdownFormat	-array-add	\\040	
com.bjango.istatmenus5.extras	Time_DropdownFormat	-array-add	h	
com.bjango.istatmenus5.extras	Time_DropdownFormat	-array-add	:	
com.bjango.istatmenus5.extras	Time_DropdownFormat	-array-add	mm	
com.bjango.istatmenus5.extras	Time_DropdownFormat	-array-add	\\040	
com.bjango.istatmenus5.extras	Time_DropdownFormat	-array-add	a	
com.bjango.istatmenus5.extras	Time_DropdownFormat	-array-add	\\040\\050	
com.bjango.istatmenus5.extras	Time_DropdownFormat	-array-add	zzz	
com.bjango.istatmenus5.extras	Time_DropdownFormat	-array-add	\\051	
com.bjango.istatmenus5.extras	Time_Cities	-array-add	4930956	
com.bjango.istatmenus5.extras	Time_Cities	-array-add	4887398	
com.bjango.istatmenus5.extras	Time_Cities	-array-add	5419384	
com.bjango.istatmenus5.extras	Time_Cities	-array-add	5392171	
com.bjango.istatmenus5.extras	Time_Cities	-array-add	5879400	
com.bjango.istatmenus5.extras	Time_Cities	-array-add	5856195	
com.bjango.istatmenus5.extras	Time_TextSize	-int	14	'

custom_istatmenus () {
  defaults delete com.bjango.istatmenus5.extras Time_MenubarFormat > /dev/null 2>&1
  defaults delete com.bjango.istatmenus5.extras Time_DropdownFormat > /dev/null 2>&1
  defaults delete com.bjango.istatmenus5.extras Time_Cities > /dev/null 2>&1
  config_defaults "${_istatmenus}"
}

# Customize Safari

_safari='com.apple.Safari	AlwaysRestoreSessionAtLaunch	-bool	false	
com.apple.Safari	OpenPrivateWindowWhenNotRestoringSessionAtLaunch	-bool	false	
com.apple.Safari	NewWindowBehavior	-int	1	
com.apple.Safari	NewTabBehavior	-int	1	
com.apple.Safari	AutoOpenSafeDownloads	-bool	false	
com.apple.Safari	TabCreationPolicy	-int	2	
com.apple.Safari	AutoFillFromAddressBook	-bool	false	
com.apple.Safari	AutoFillPasswords	-bool	true	
com.apple.Safari	AutoFillCreditCardData	-bool	false	
com.apple.Safari	AutoFillMiscellaneousForms	-bool	false	
com.apple.Safari	SuppressSearchSuggestions	-bool	false	
com.apple.Safari	UniversalSearchEnabled	-bool	false	
com.apple.Safari	WebsiteSpecificSearchEnabled	-bool	true	
com.apple.Safari	PreloadTopHit	-bool	true	
com.apple.Safari	ShowFavoritesUnderSmartSearchField	-bool	false	
com.apple.Safari	SafariGeolocationPermissionPolicy	-int	0	
com.apple.Safari	BlockStoragePolicy	-int	2	
com.apple.Safari	WebKitStorageBlockingPolicy	-int	1	
com.apple.Safari	com.apple.Safari.ContentPageGroupIdentifier.WebKit2StorageBlockingPolicy	-int	1	
com.apple.Safari	SendDoNotTrackHTTPHeader	-bool	true	
com.apple.WebFoundation	NSHTTPAcceptCookies	-string	always	
com.apple.Safari	com.apple.Safari.ContentPageGroupIdentifier.WebKit2ApplePayCapabilityDisclosureAllowed	-bool	true	
com.apple.Safari	CanPromptForPushNotifications	-bool	false	
com.apple.Safari	ShowFullURLInSmartSearchField	-bool	true	
com.apple.Safari	WebKitDefaultTextEncodingName	-string	utf-8	
com.apple.Safari	com.apple.Safari.ContentPageGroupIdentifier.WebKit2DefaultTextEncodingName	-string	utf-8	
com.apple.Safari	IncludeDevelopMenu	-bool	true	
com.apple.Safari	WebKitDeveloperExtrasEnabledPreferenceKey	-bool	true	
com.apple.Safari	com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled	-bool	true	
com.apple.Safari	ShowFavoritesBar-v2	-bool	true	
com.apple.Safari	AlwaysShowTabBar	-bool	true	
com.apple.Safari	ShowStatusBar	-bool	true	
com.apple.Safari	ShowStatusBarInFullScreen	-bool	true	'

custom_safari () {
  config_defaults "${_safari}"
}

# Customize Sieve

custom_sieve () {
  cat > "${HOME}/.sieve" << EOF
require ["date", "fileinto", "imap4flags", "mailbox", "relational", "variables"];
setflag "\\\\Seen";
if date :is "date" "year" "1995" { fileinto :create "Archives.1995"; }
if date :is "date" "year" "1996" { fileinto :create "Archives.1996"; }
if date :is "date" "year" "1997" { fileinto :create "Archives.1997"; }
if date :is "date" "year" "1998" { fileinto :create "Archives.1998"; }
if date :is "date" "year" "1999" { fileinto :create "Archives.1999"; }
if date :is "date" "year" "2000" { fileinto :create "Archives.2000"; }
if date :is "date" "year" "2001" { fileinto :create "Archives.2001"; }
if date :is "date" "year" "2002" { fileinto :create "Archives.2002"; }
if date :is "date" "year" "2003" { fileinto :create "Archives.2003"; }
if date :is "date" "year" "2004" { fileinto :create "Archives.2004"; }
if date :is "date" "year" "2005" { fileinto :create "Archives.2005"; }
if date :is "date" "year" "2006" { fileinto :create "Archives.2006"; }
if date :is "date" "year" "2007" { fileinto :create "Archives.2007"; }
if date :is "date" "year" "2008" { fileinto :create "Archives.2008"; }
if date :is "date" "year" "2009" { fileinto :create "Archives.2009"; }
if date :is "date" "year" "2010" { fileinto :create "Archives.2010"; }
if date :is "date" "year" "2011" { fileinto :create "Archives.2011"; }
if date :is "date" "year" "2012" { fileinto :create "Archives.2012"; }
if date :is "date" "year" "2013" { fileinto :create "Archives.2013"; }
if date :is "date" "year" "2014" { fileinto :create "Archives.2014"; }
if date :is "date" "year" "2015" { fileinto :create "Archives.2015"; }
if date :is "date" "year" "2016" { fileinto :create "Archives.2016"; }
if date :is "date" "year" "2017" { fileinto :create "Archives.2017"; }
if date :is "date" "year" "2018" { fileinto :create "Archives.2018"; }
if date :is "date" "year" "2019" { fileinto :create "Archives.2019"; }
if date :is "date" "year" "2020" { fileinto :create "Archives.2020"; }
EOF
}

# Customize Sonarr

_sonarr='Advanced Settings	Shown
Rename Episodes	Yes
Standard Episode Format	{Series Title} - s{season:00}e{episode:00} - {Episode Title}
Daily Episode Format	{Series Title} - {Air-Date} - {Episode Title}
Anime Episode Format	{Series Title} - s{season:00}e{episode:00} - {Episode Title}
Multi-Episode Style	Scene
Create empty series folders	Yes
Ignore Deleted Episodes	Yes
Change File Date	UTC Air Date
Set Permissions	Yes
Download Clients	NZBGet
NZBGet: Name	NZBGet
NZBGet: Category	Sonarr
Failed: Remove	No
Drone Factory Interval	0
Connect: Custom Script	
postSonarr: Name	postSonarr
postSonarr: On Grab	No
postSonarr: On Download	Yes
postSonarr: On Upgrade	Yes
postSonarr: On Rename	No
postSonarr: Path	${HOME}/.config/mp4_automator/postSonarr.py
Start-Up: Open browser on start	No
Security: Authentication	Basic (Browser popup)'

custom_sonarr () {
  open "http://localhost:7878/settings/mediamanagement"
  open "http://localhost:8989/settings/mediamanagement"
  printf "%s" "$_sonarr" | \
  while IFS="$(printf '\t')" read pref value; do
    printf "\033[1m\033[34m%s:\033[0m %s\n" "$pref" "$value"
  done
}

# Customize SSH

custom_ssh () {
  if ! test -d "${HOME}/.ssh"; then
    mkdir -m go= "${HOME}/.ssh"
    e="$(ask 'New SSH Key: Email Address?' 'OK' '')"
    ssh-keygen -t ed25519 -a 100 -C "$e"
    cat << EOF > "${HOME}/.ssh/config"
Host *
  AddKeysToAgent yes
  IdentityFile ~/.ssh/id_ed25519
EOF
    pbcopy < "${HOME}/.ssh/id_ed25519.pub"
    open "https://github.com/settings/keys"
  fi
}

# Customize System Preferences

custom_sysprefs () {
  custom_general
  custom_desktop "/Library/Desktop Pictures/Solid Colors/Solid Black.png"
  custom_screensaver
  custom_dock
  custom_dockapps
  # custom_security
  custom_text
  custom_dictation
  custom_mouse
  custom_trackpad
  custom_sound
  custom_loginitems
  custom_siri
  custom_clock
  custom_a11y
  custom_other
}

# Customize General

_general='-globalDomain	AppleAquaColorVariant	-int	6	
-globalDomain	AppleInterfaceStyle	-string	Dark	
-globalDomain	_HIHideMenuBar	-bool	false	
-globalDomain	AppleHighlightColor	-string	0.600000 0.800000 0.600000	
-globalDomain	NSTableViewDefaultSizeMode	-int	1	
-globalDomain	AppleShowScrollBars	-string	Always	
-globalDomain	AppleScrollerPagingBehavior	-bool	false	
-globalDomain	NSCloseAlwaysConfirmsChanges	-bool	true	
-globalDomain	NSQuitAlwaysKeepsWindows	-bool	false	
com.apple.coreservices.useractivityd	ActivityAdvertisingAllowed	-bool	true	-currentHost
com.apple.coreservices.useractivityd	ActivityReceivingAllowed	-bool	true	-currentHost
-globalDomain	AppleFontSmoothing	-int	1	-currentHost'

custom_general () {
  osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to true'
  config_defaults "${_general}"
  osascript << EOF
    tell application "System Events"
      tell appearance preferences
        set recent documents limit to 0
        set recent applications limit to 0
        set recent servers limit to 0
      end tell
    end tell
EOF
}

# Customize Desktop Picture

custom_desktop () {
  osascript - "${1}" << EOF 2> /dev/null
    on run { _this }
      tell app "System Events" to set picture of every desktop to POSIX file _this
    end run
EOF
}

# Customize Screen Saver

_screensaver='com.apple.screensaver	idleTime	-int	0	-currentHost
com.apple.dock	wvous-tl-corner	-int	2	
com.apple.dock	wvous-tl-modifier	-int	1048576	
com.apple.dock	wvous-bl-corner	-int	10	
com.apple.dock	wvous-bl-modifier	-int	0	'

custom_screensaver () {
  if test -e "/Library/Screen Savers/BlankScreen.saver"; then
    defaults -currentHost write com.apple.screensaver moduleDict \
      '{
        moduleName = "BlankScreen";
        path = "/Library/Screen Savers/BlankScreen.saver";
        type = 0;
      }'
  fi
  config_defaults "${_screensaver}"
}

# Customize Dock

_dock='com.apple.dock	tilesize	-int	32	
com.apple.dock	magnification	-bool	false	
com.apple.dock	largesize	-int	64	
com.apple.dock	orientation	-string	right	
com.apple.dock	mineffect	-string	scale	
-globalDomain	AppleWindowTabbingMode	-string	always	
-globalDomain	AppleActionOnDoubleClick	-string	None	
com.apple.dock	minimize-to-application	-bool	true	
com.apple.dock	launchanim	-bool	false	
com.apple.dock	autohide	-bool	true	
com.apple.dock	show-process-indicators	-bool	true	'

custom_dock () {
  config_defaults "${_dock}"
}

# Customize Dock Apps

_dockapps='Metanota Pro
Mail
Safari
Messages
Emacs
BBEdit
Atom
Utilities/Terminal
iTerm
System Preferences
PCalc
Hermes
iTunes
VLC'

custom_dockapps () {
  defaults write com.apple.dock "autohide-delay" -float 0
  defaults write com.apple.dock "autohide-time-modifier" -float 0.5

  defaults delete com.apple.dock "persistent-apps"

  printf "%s\n" "${_dockapps}" | \
  while IFS="$(printf '\t')" read app; do
    if test -e "/Applications/${app}.app"; then
      defaults write com.apple.dock "persistent-apps" -array-add \
        "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>/Applications/${app}.app/</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>"
    fi
  done

  defaults delete com.apple.dock "persistent-others"

  osascript -e 'tell app "Dock" to quit'
}

# Customize Security

_security='com.apple.screensaver	askForPassword	-int	1	
com.apple.screensaver	askForPasswordDelay	-int	5	'

custom_security () {
  config_defaults "${_security}"
}

# Customize Text

_text='-globalDomain	NSAutomaticCapitalizationEnabled	-bool	false	
-globalDomain	NSAutomaticPeriodSubstitutionEnabled	-bool	false	
-globalDomain	NSAutomaticQuoteSubstitutionEnabled	-bool	false	'
custom_text () {
  config_defaults "${_text}"
}

# Customize Dictation

_dictation='com.apple.speech.recognition.AppleSpeechRecognition.prefs	DictationIMMasterDictationEnabled	-bool	true	'

custom_dictation () {
  config_defaults "${_dictation}"
}

# Customize Mouse

_mouse='-globalDomain	com.apple.swipescrolldirection	-bool	false	'

custom_mouse () {
  config_defaults "${_mouse}"
}

# Customize Trackpad

_trackpad='com.apple.driver.AppleBluetoothMultitouch.trackpad	Clicking	-bool	true	
-globalDomain	com.apple.mouse.tapBehavior	-int	1	-currentHost'

custom_trackpad () {
  config_defaults "${_trackpad}"
}

# Customize Sound

_sound='-globalDomain	com.apple.sound.beep.sound	-string	/System/Library/Sounds/Sosumi.aiff	
-globalDomain	com.apple.sound.uiaudio.enabled	-int	0	
-globalDomain	com.apple.sound.beep.feedback	-int	0	'

custom_sound () {
  config_defaults "${_sound}"
}

# Customize Login Items

_loginitems='/Applications/Alfred 3.app
/Applications/autoping.app
/Applications/Caffeine.app
/Applications/Coffitivity.app
/Applications/Dropbox.app
/Applications/HardwareGrowler.app
/Applications/I Love Stars.app
/Applications/IPMenulet.app
/Applications/iTunes.app/Contents/MacOS/iTunesHelper.app
/Applications/Menubar Countdown.app
/Applications/Meteorologist.app
/Applications/Moom.app
/Applications/NZBGet.app
/Applications/Plex Media Server.app
/Applications/Radarr.app
/Applications/Sonarr-Menu.app
/Library/PreferencePanes/SteerMouse.prefPane/Contents/MacOS/SteerMouse Manager.app'
custom_loginitems () {
  printf "%s\n" "${_loginitems}" | \
  while IFS="$(printf '\t')" read app; do
    if test -e "$app"; then
      osascript - "$app" << EOF > /dev/null
        on run { _app }
          tell app "System Events"
            make new login item with properties { hidden: true, path: _app }
          end tell
        end run
EOF
    fi
  done
}

# Customize Siri

custom_siri () {
  defaults write com.apple.assistant.backedup "Output Voice" \
    '{
      Custom = 1;
      Footprint = 0;
      Gender = 1;
      Language = "en-US";
    }'
  defaults write com.apple.Siri StatusMenuVisible -bool false
}

# Customize Clock

custom_clock () {
  defaults -currentHost write com.apple.systemuiserver dontAutoLoad \
    -array-add "/System/Library/CoreServices/Menu Extras/Clock.menu"
  defaults write com.apple.menuextra.clock DateFormat \
    -string "EEE MMM d  h:mm:ss a"
}

# Customize Accessibility

_a11y='com.apple.universalaccess	reduceTransparency	-bool	true	'
_speech='com.apple.speech.voice.prefs	SelectedVoiceName	-string	Allison	
com.apple.speech.voice.prefs	SelectedVoiceCreator	-int	1886745202	
com.apple.speech.voice.prefs	SelectedVoiceID	-int	184555197	'

custom_a11y () {
  config_defaults "${_a11y}"

  if test -d "/System/Library/Speech/Voices/Allison.SpeechVoice"; then
    config_defaults "${_speech}"
    defaults write com.apple.speech.voice.prefs VisibleIdentifiers \
      '{
        "com.apple.speech.synthesis.voice.allison.premium" = 1;
      }'
  fi
}

# Customize Other Prefs

_other_prefs='Security & Privacy	General	com.apple.preference.security	General	/System/Library/PreferencePanes/Security.prefPane/Contents/Resources/FileVault.icns
Security & Privacy	FileVault	com.apple.preference.security	FDE	/System/Library/PreferencePanes/Security.prefPane/Contents/Resources/FileVault.icns
Security & Privacy	Accessibility	com.apple.preference.security	Privacy_Accessibility	/System/Library/PreferencePanes/Security.prefPane/Contents/Resources/FileVault.icns
Displays	Display	com.apple.preference.displays	displaysDisplayTab	/System/Library/PreferencePanes/Displays.prefPane/Contents/Resources/Displays.icns
Keyboard	Modifer Keys	com.apple.preference.keyboard	keyboardTab_ModifierKeys	/System/Library/PreferencePanes/Keyboard.prefPane/Contents/Resources/Keyboard.icns
Keyboard	Text	com.apple.preference.keyboard	Text	/System/Library/PreferencePanes/Keyboard.prefPane/Contents/Resources/Keyboard.icns
Keyboard	Shortcuts	com.apple.preference.keyboard	shortcutsTab	/System/Library/PreferencePanes/Keyboard.prefPane/Contents/Resources/Keyboard.icns
Keyboard	Dictation	com.apple.preference.keyboard	Dictation	/System/Library/PreferencePanes/Keyboard.prefPane/Contents/Resources/Keyboard.icns
Printers & Scanners	Main	com.apple.preference.printfax	print	/System/Library/PreferencePanes/PrintAndScan.prefPane/Contents/Resources/PrintScanPref.icns
Internet Accounts	Main	com.apple.preferences.internetaccounts	InternetAccounts	/System/Library/PreferencePanes/iCloudPref.prefPane/Contents/Resources/iCloud.icns
Network	Wi-Fi	com.apple.preference.network	Wi-Fi	/System/Library/PreferencePanes/Network.prefPane/Contents/Resources/Network.icns
Users & Groups	Login Options	com.apple.preferences.users	loginOptionsPref	/System/Library/PreferencePanes/Accounts.prefPane/Contents/Resources/AccountsPref.icns
Time Machine	Main	com.apple.prefs.backup	main	/System/Library/PreferencePanes/TimeMachine.prefPane/Contents/Resources/TimeMachine.icns'
custom_other () {
  T=$(printf '\t')
  printf "%s\n" "$_other_prefs" | \
  while IFS="$T" read pane anchor paneid anchorid icon; do
    osascript - "$pane" "$anchor" "$paneid" "$anchorid" "$icon" << EOF 2> /dev/null
  on run { _pane, _anchor, _paneid, _anchorid, _icon }
    tell app "System Events"
      display dialog "Open the " & _anchor & " pane of " & _pane & " preferences." buttons { "Open " & _pane } default button 1 with icon POSIX file _icon
    end tell
    tell app "System Preferences"
      if not running then run
      reveal anchor _anchorid of pane id _paneid
      activate
    end tell
  end run
EOF
  done
}

# Customize Terminal

_term_plist='delete			
add	:		dict
add	:name	string	ptb
add	:type	string	Window Settings
add	:ProfileCurrentVersion	real	2.05
add	:BackgroundColor	data	<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>$archiver</key><string>NSKeyedArchiver</string><key>$objects</key><array><string>$null</string><dict><key>$class</key><dict><key>CF$UID</key><integer>2</integer></dict><key>NSColorSpace</key><integer>1</integer><key>NSRGB</key><data>MC4xIDAuMSAwLjE=</data></dict><dict><key>$classes</key><array><string>NSColor</string><string>NSObject</string></array><key>$classname</key><string>NSColor</string></dict></array><key>$top</key><dict><key>root</key><dict><key>CF$UID</key><integer>1</integer></dict></dict><key>$version</key><integer>100000</integer></dict></plist>
add	:BackgroundBlur	real	0
add	:BackgroundSettingsForInactiveWindows	bool	false
add	:BackgroundAlphaInactive	real	1
add	:BackgroundBlurInactive	real	0
add	:Font	data	<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>$archiver</key><string>NSKeyedArchiver</string><key>$objects</key><array><string>$null</string><dict><key>$class</key><dict><key>CF$UID</key><integer>3</integer></dict><key>NSName</key><dict><key>CF$UID</key><integer>2</integer></dict><key>NSSize</key><real>13</real><key>NSfFlags</key><integer>16</integer></dict><string>InconsolataLGC</string><dict><key>$classes</key><array><string>NSFont</string><string>NSObject</string></array><key>$classname</key><string>NSFont</string></dict></array><key>$top</key><dict><key>root</key><dict><key>CF$UID</key><integer>1</integer></dict></dict><key>$version</key><integer>100000</integer></dict></plist>
add	:FontWidthSpacing	real	1
add	:FontHeightSpacing	real	1
add	:FontAntialias	bool	true
add	:UseBoldFonts	bool	true
add	:BlinkText	bool	false
add	:DisableANSIColor	bool	false
add	:UseBrightBold	bool	false
add	:TextColor	data	<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>$archiver</key><string>NSKeyedArchiver</string><key>$objects</key><array><string>$null</string><dict><key>$class</key><dict><key>CF$UID</key><integer>2</integer></dict><key>NSColorSpace</key><integer>1</integer><key>NSRGB</key><data>MC44IDAuOCAwLjg=</data></dict><dict><key>$classes</key><array><string>NSColor</string><string>NSObject</string></array><key>$classname</key><string>NSColor</string></dict></array><key>$top</key><dict><key>root</key><dict><key>CF$UID</key><integer>1</integer></dict></dict><key>$version</key><integer>100000</integer></dict></plist>
add	:TextBoldColor	data	<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>$archiver</key><string>NSKeyedArchiver</string><key>$objects</key><array><string>$null</string><dict><key>$class</key><dict><key>CF$UID</key><integer>2</integer></dict><key>NSColorSpace</key><integer>1</integer><key>NSRGB</key><data>MC44IDAuOCAwLjg=</data></dict><dict><key>$classes</key><array><string>NSColor</string><string>NSObject</string></array><key>$classname</key><string>NSColor</string></dict></array><key>$top</key><dict><key>root</key><dict><key>CF$UID</key><integer>1</integer></dict></dict><key>$version</key><integer>100000</integer></dict></plist>
add	:SelectionColor	data	<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>$archiver</key><string>NSKeyedArchiver</string><key>$objects</key><array><string>$null</string><dict><key>$class</key><dict><key>CF$UID</key><integer>2</integer></dict><key>NSColorSpace</key><integer>1</integer><key>NSRGB</key><data>MC4zIDAuMyAwLjM=</data></dict><dict><key>$classes</key><array><string>NSColor</string><string>NSObject</string></array><key>$classname</key><string>NSColor</string></dict></array><key>$top</key><dict><key>root</key><dict><key>CF$UID</key><integer>1</integer></dict></dict><key>$version</key><integer>100000</integer></dict></plist>
add	:ANSIBlackColor	data	<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>$archiver</key><string>NSKeyedArchiver</string><key>$objects</key><array><string>$null</string><dict><key>$class</key><dict><key>CF$UID</key><integer>2</integer></dict><key>NSColorSpace</key><integer>1</integer><key>NSRGB</key><data>MC4zIDAuMyAwLjM=</data></dict><dict><key>$classes</key><array><string>NSColor</string><string>NSObject</string></array><key>$classname</key><string>NSColor</string></dict></array><key>$top</key><dict><key>root</key><dict><key>CF$UID</key><integer>1</integer></dict></dict><key>$version</key><integer>100000</integer></dict></plist>
add	:ANSIRedColor	data	<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>$archiver</key><string>NSKeyedArchiver</string><key>$objects</key><array><string>$null</string><dict><key>$class</key><dict><key>CF$UID</key><integer>2</integer></dict><key>NSColorSpace</key><integer>1</integer><key>NSRGB</key><data>MC45NSAwLjUgMC41</data></dict><dict><key>$classes</key><array><string>NSColor</string><string>NSObject</string></array><key>$classname</key><string>NSColor</string></dict></array><key>$top</key><dict><key>root</key><dict><key>CF$UID</key><integer>1</integer></dict></dict><key>$version</key><integer>100000</integer></dict></plist>
add	:ANSIGreenColor	data	<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>$archiver</key><string>NSKeyedArchiver</string><key>$objects</key><array><string>$null</string><dict><key>$class</key><dict><key>CF$UID</key><integer>2</integer></dict><key>NSColorSpace</key><integer>1</integer><key>NSRGB</key><data>MC42IDAuOCAwLjY=</data></dict><dict><key>$classes</key><array><string>NSColor</string><string>NSObject</string></array><key>$classname</key><string>NSColor</string></dict></array><key>$top</key><dict><key>root</key><dict><key>CF$UID</key><integer>1</integer></dict></dict><key>$version</key><integer>100000</integer></dict></plist>
add	:ANSIYellowColor	data	<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>$archiver</key><string>NSKeyedArchiver</string><key>$objects</key><array><string>$null</string><dict><key>$class</key><dict><key>CF$UID</key><integer>2</integer></dict><key>NSColorSpace</key><integer>1</integer><key>NSRGB</key><data>MSAwLjggMC40</data></dict><dict><key>$classes</key><array><string>NSColor</string><string>NSObject</string></array><key>$classname</key><string>NSColor</string></dict></array><key>$top</key><dict><key>root</key><dict><key>CF$UID</key><integer>1</integer></dict></dict><key>$version</key><integer>100000</integer></dict></plist>
add	:ANSIBlueColor	data	<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>$archiver</key><string>NSKeyedArchiver</string><key>$objects</key><array><string>$null</string><dict><key>$class</key><dict><key>CF$UID</key><integer>2</integer></dict><key>NSColorSpace</key><integer>1</integer><key>NSRGB</key><data>MC40IDAuNiAwLjg=</data></dict><dict><key>$classes</key><array><string>NSColor</string><string>NSObject</string></array><key>$classname</key><string>NSColor</string></dict></array><key>$top</key><dict><key>root</key><dict><key>CF$UID</key><integer>1</integer></dict></dict><key>$version</key><integer>100000</integer></dict></plist>
add	:ANSIMagentaColor	data	<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>$archiver</key><string>NSKeyedArchiver</string><key>$objects</key><array><string>$null</string><dict><key>$class</key><dict><key>CF$UID</key><integer>2</integer></dict><key>NSColorSpace</key><integer>1</integer><key>NSRGB</key><data>MC44IDAuNiAwLjg=</data></dict><dict><key>$classes</key><array><string>NSColor</string><string>NSObject</string></array><key>$classname</key><string>NSColor</string></dict></array><key>$top</key><dict><key>root</key><dict><key>CF$UID</key><integer>1</integer></dict></dict><key>$version</key><integer>100000</integer></dict></plist>
add	:ANSICyanColor	data	<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>$archiver</key><string>NSKeyedArchiver</string><key>$objects</key><array><string>$null</string><dict><key>$class</key><dict><key>CF$UID</key><integer>2</integer></dict><key>NSColorSpace</key><integer>1</integer><key>NSRGB</key><data>MC40IDAuOCAwLjg=</data></dict><dict><key>$classes</key><array><string>NSColor</string><string>NSObject</string></array><key>$classname</key><string>NSColor</string></dict></array><key>$top</key><dict><key>root</key><dict><key>CF$UID</key><integer>1</integer></dict></dict><key>$version</key><integer>100000</integer></dict></plist>
add	:ANSIWhiteColor	data	<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>$archiver</key><string>NSKeyedArchiver</string><key>$objects</key><array><string>$null</string><dict><key>$class</key><dict><key>CF$UID</key><integer>2</integer></dict><key>NSColorSpace</key><integer>1</integer><key>NSRGB</key><data>MC44IDAuOCAwLjg=</data></dict><dict><key>$classes</key><array><string>NSColor</string><string>NSObject</string></array><key>$classname</key><string>NSColor</string></dict></array><key>$top</key><dict><key>root</key><dict><key>CF$UID</key><integer>1</integer></dict></dict><key>$version</key><integer>100000</integer></dict></plist>
add	:ANSIBrightBlackColor	data	<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>$archiver</key><string>NSKeyedArchiver</string><key>$objects</key><array><string>$null</string><dict><key>$class</key><dict><key>CF$UID</key><integer>2</integer></dict><key>NSColorSpace</key><integer>1</integer><key>NSRGB</key><data>MC41IDAuNSAwLjU=</data></dict><dict><key>$classes</key><array><string>NSColor</string><string>NSObject</string></array><key>$classname</key><string>NSColor</string></dict></array><key>$top</key><dict><key>root</key><dict><key>CF$UID</key><integer>1</integer></dict></dict><key>$version</key><integer>100000</integer></dict></plist>
add	:ANSIBrightRedColor	data	<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>$archiver</key><string>NSKeyedArchiver</string><key>$objects</key><array><string>$null</string><dict><key>$class</key><dict><key>CF$UID</key><integer>2</integer></dict><key>NSColorSpace</key><integer>1</integer><key>NSRGB</key><data>MSAwLjcgMC43</data></dict><dict><key>$classes</key><array><string>NSColor</string><string>NSObject</string></array><key>$classname</key><string>NSColor</string></dict></array><key>$top</key><dict><key>root</key><dict><key>CF$UID</key><integer>1</integer></dict></dict><key>$version</key><integer>100000</integer></dict></plist>
add	:ANSIBrightGreenColor	data	<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>$archiver</key><string>NSKeyedArchiver</string><key>$objects</key><array><string>$null</string><dict><key>$class</key><dict><key>CF$UID</key><integer>2</integer></dict><key>NSColorSpace</key><integer>1</integer><key>NSRGB</key><data>MC44IDEgMC44</data></dict><dict><key>$classes</key><array><string>NSColor</string><string>NSObject</string></array><key>$classname</key><string>NSColor</string></dict></array><key>$top</key><dict><key>root</key><dict><key>CF$UID</key><integer>1</integer></dict></dict><key>$version</key><integer>100000</integer></dict></plist>
add	:ANSIBrightYellowColor	data	<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>$archiver</key><string>NSKeyedArchiver</string><key>$objects</key><array><string>$null</string><dict><key>$class</key><dict><key>CF$UID</key><integer>2</integer></dict><key>NSColorSpace</key><integer>1</integer><key>NSRGB</key><data>MSAxIDAuNg==</data></dict><dict><key>$classes</key><array><string>NSColor</string><string>NSObject</string></array><key>$classname</key><string>NSColor</string></dict></array><key>$top</key><dict><key>root</key><dict><key>CF$UID</key><integer>1</integer></dict></dict><key>$version</key><integer>100000</integer></dict></plist>
add	:ANSIBrightBlueColor	data	<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>$archiver</key><string>NSKeyedArchiver</string><key>$objects</key><array><string>$null</string><dict><key>$class</key><dict><key>CF$UID</key><integer>2</integer></dict><key>NSColorSpace</key><integer>1</integer><key>NSRGB</key><data>MC42IDAuOCAx</data></dict><dict><key>$classes</key><array><string>NSColor</string><string>NSObject</string></array><key>$classname</key><string>NSColor</string></dict></array><key>$top</key><dict><key>root</key><dict><key>CF$UID</key><integer>1</integer></dict></dict><key>$version</key><integer>100000</integer></dict></plist>
add	:ANSIBrightMagentaColor	data	<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>$archiver</key><string>NSKeyedArchiver</string><key>$objects</key><array><string>$null</string><dict><key>$class</key><dict><key>CF$UID</key><integer>2</integer></dict><key>NSColorSpace</key><integer>1</integer><key>NSRGB</key><data>MSAwLjggMQ==</data></dict><dict><key>$classes</key><array><string>NSColor</string><string>NSObject</string></array><key>$classname</key><string>NSColor</string></dict></array><key>$top</key><dict><key>root</key><dict><key>CF$UID</key><integer>1</integer></dict></dict><key>$version</key><integer>100000</integer></dict></plist>
add	:ANSIBrightCyanColor	data	<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>$archiver</key><string>NSKeyedArchiver</string><key>$objects</key><array><string>$null</string><dict><key>$class</key><dict><key>CF$UID</key><integer>2</integer></dict><key>NSColorSpace</key><integer>1</integer><key>NSRGB</key><data>MC42IDEgMQ==</data></dict><dict><key>$classes</key><array><string>NSColor</string><string>NSObject</string></array><key>$classname</key><string>NSColor</string></dict></array><key>$top</key><dict><key>root</key><dict><key>CF$UID</key><integer>1</integer></dict></dict><key>$version</key><integer>100000</integer></dict></plist>
add	:ANSIBrightWhiteColor	data	<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>$archiver</key><string>NSKeyedArchiver</string><key>$objects</key><array><string>$null</string><dict><key>$class</key><dict><key>CF$UID</key><integer>2</integer></dict><key>NSColorSpace</key><integer>1</integer><key>NSRGB</key><data>MC45IDAuOSAwLjk=</data></dict><dict><key>$classes</key><array><string>NSColor</string><string>NSObject</string></array><key>$classname</key><string>NSColor</string></dict></array><key>$top</key><dict><key>root</key><dict><key>CF$UID</key><integer>1</integer></dict></dict><key>$version</key><integer>100000</integer></dict></plist>
add	:CursorType	integer	0
add	:CursorBlink	bool	false
add	:CursorColor	data	<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>$archiver</key><string>NSKeyedArchiver</string><key>$objects</key><array><string>$null</string><dict><key>$class</key><dict><key>CF$UID</key><integer>2</integer></dict><key>NSColorSpace</key><integer>1</integer><key>NSRGB</key><data>MC43IDAuNyAwLjc=</data></dict><dict><key>$classes</key><array><string>NSColor</string><string>NSObject</string></array><key>$classname</key><string>NSColor</string></dict></array><key>$top</key><dict><key>root</key><dict><key>CF$UID</key><integer>1</integer></dict></dict><key>$version</key><integer>100000</integer></dict></plist>
add	:ShowRepresentedURLInTitle	bool	true
add	:ShowRepresentedURLPathInTitle	bool	true
add	:ShowActiveProcessInTitle	bool	true
add	:ShowActiveProcessArgumentsInTitle	bool	false
add	:ShowShellCommandInTitle	bool	false
add	:ShowWindowSettingsNameInTitle	bool	false
add	:ShowTTYNameInTitle	bool	false
add	:ShowDimensionsInTitle	bool	false
add	:ShowCommandKeyInTitle	bool	false
add	:columnCount	integer	121
add	:rowCount	integer	35
add	:ShouldLimitScrollback	integer	0
add	:ScrollbackLines	integer	0
add	:ShouldRestoreContent	bool	false
add	:ShowRepresentedURLInTabTitle	bool	false
add	:ShowRepresentedURLPathInTabTitle	bool	false
add	:ShowActiveProcessInTabTitle	bool	true
add	:ShowActiveProcessArgumentsInTabTitle	bool	false
add	:ShowTTYNameInTabTitle	bool	false
add	:ShowComponentsWhenTabHasCustomTitle	bool	true
add	:ShowActivityIndicatorInTab	bool	true
add	:shellExitAction	integer	1
add	:warnOnShellCloseAction	integer	1
add	:useOptionAsMetaKey	bool	false
add	:ScrollAlternateScreen	bool	true
add	:TerminalType	string	xterm-256color
add	:deleteSendsBackspace	bool	false
add	:EscapeNonASCIICharacters	bool	true
add	:ConvertNewlinesOnPaste	bool	true
add	:StrictVTKeypad	bool	true
add	:scrollOnInput	bool	true
add	:Bell	bool	false
add	:VisualBell	bool	false
add	:VisualBellOnlyWhenMuted	bool	false
add	:BellBadge	bool	false
add	:BellBounce	bool	false
add	:BellBounceCritical	bool	false
add	:CharacterEncoding	integer	4
add	:SetLanguageEnvironmentVariables	bool	true
add	:EastAsianAmbiguousWide	bool	false'
_term_defaults='com.apple.Terminal	Startup Window Settings	-string	ptb	
com.apple.Terminal	Default Window Settings	-string	ptb	'

custom_terminal () {
  config_plist "${_term_plist}" \
    "${HOME}/Library/Preferences/com.apple.Terminal.plist" \
    ":Window Settings:ptb"
  config_defaults "${_term_defaults}"
}

# Customize Vim

custom_vim () {
  true
}

# Customize VLC

_vlc_defaults='org.videolan.vlc	SUEnableAutomaticChecks	-bool	true	
org.videolan.vlc	SUHasLaunchedBefore	-bool	true	
org.videolan.vlc	SUSendProfileInfo	-bool	true	'
_vlcrc='macosx	macosx-nativefullscreenmode	1
macosx	macosx-video-autoresize	0
macosx	macosx-appleremote	0
macosx	macosx-pause-minimized	1
macosx	macosx-continue-playback	1
core	metadata-network-access	1
core	volume-save	0
core	spdif	1
core	sub-language	English
core	medium-jump-size	30
subsdec	subsdec-encoding	UTF-8
avcodec	avcodec-hw	vda'

custom_vlc () {
  config_defaults "${_vlc_defaults}"
  if which crudini > /dev/null; then
    test -d "${HOME}/Library/Preferences/org.videolan.vlc" || \
      mkdir -p "${HOME}/Library/Preferences/org.videolan.vlc"
    printf "%s\n" "${_vlcrc}" | \
    while IFS="$(printf '\t')" read section key value; do
      crudini --set "${HOME}/Library/Preferences/org.videolan.vlc/vlcrc" "${section}" "${key}" "${value}"
    done
  fi
}

# Define Function =personalize=

personalize () {
  printf "%b" "$(echo "${1}" | openssl enc -aes-256-ecb -a -d -pass "pass:${CRYPTPASS}")" | sh
}

# Log Out Then Log Back In

personalize_logout () {
  /usr/bin/read -n 1 -p "Press any key to continue.
" -s
  if run "Log Out Then Log Back In?" "Cancel" "Log Out"; then
    osascript -e 'tell app "loginwindow" to «event aevtrlgo»'
  fi
}