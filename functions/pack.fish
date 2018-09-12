function pack -d 'vim8/neovim package manager using git submodules'
  function __help 
    echo "usage: pack install [<name>...]
       pack remove [<name>...]
       pack list" 1>&2
    return 1
  end
  
  function __install -a config_dir package
    set -l repo (string split -r '/' $package)

    git -C $config_dir submodule add --name $package --depth 1 \
      https://github.com/$package.git pack/gitmodules/start/$repo[2]
    git -C $config_dir config -f .gitmodules submodule.$package.shallow true
    # git -C $config_dir add .gitmodules
    # git -C $config_dir commit -m "Add $package package"
  end
  
  function __update -a config_dir
    git -C $config_dir submodule update --jobs 8 --remote --init --rebase
  end
 
  function __list -a config_dir
    set -l out (git -C $config_dir config -f .gitmodules --get-regexp 'submodule\..*.path')
    string replace -ar 'submodule\.|\.path' '' $out
  end
  
  function __remove -a config_dir package
    git -C $config_dir submodule deinit $package
    git -C $config_dir rm $package
  end
  # argparse --name='pack' 'h/help' 'v/verbose' -- $argv
  # echo $_flag_help
  
  count $argv > /dev/null; or __help; or return $status
  
  # TODO: check for environment variable?
  set -l config_dir (string split ',' (vim --cmd 'echo &rtp|q' 2>&1))[1]
  
  switch $argv[1]
    case i install a add
      for package in $argv[2..-1]
        __install $config_dir $package
      end
    case up update upgrade
      for package in $argv[2..-1]
        __update $config_dir $package
      end
    case rm remove
      for package in $argv[2..-1]
        __remove $config_dir $package
      end
    case ls list 
      __list $config_dir
    case '*'
      __help
  end
  
  return $status
end

