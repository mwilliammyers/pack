function pack -d 'vim8/neovim package manager using git submodules'
  function __install -a config_dir package
    set -l repo (string split -r '/' $package)

    git -C $config_dir submodule add --name $package --depth 1 \
      https://github.com/$package.git pack/gitmodules/start/$repo[2]
      and git -C $config_dir config -f .gitmodules submodule.$package.shallow true
    # git -C $config_dir add .gitmodules
    # git -C $config_dir commit -m "Add $package package"
  end
  
  function __update -a config_dir
    git -C $config_dir submodule update --jobs 8 --remote --init --rebase
  end
 
  function __list -a config_dir -a is_verbose
    set -l out (git -C $config_dir config -f .gitmodules --get-regexp 'submodule\..*.path')
    set -l packages (string replace -ar 'submodule\.|\.path| pack/.*$' '' $out)
    
    for package_status in (git -C $config_dir submodule status)
      set -l info (string split ' ' $package_status)
      # TODO: does this work in all cases?
      set -l name (string split '/' $info[3])[-1]
      
      set -l package (string match -r "\S+/$name\$" $packages)
      
      if test -z $is_verbose
        echo $package
      else
        echo -se "$package\t$info"
      end
    end
  end
  
  function __remove -a config_dir package
    # TODO: safe to assume it will be in config file?
    set -l path (git -C $config_dir config -f .gitmodules "submodule.$package.path")
    
    set -l safe_path_regex '\.\.?/*|^\s*$' 
    # not sure how this would happen, but let's be safe...
    if string match --invert -r $safe_path_regex $path ^/dev/null >/dev/null
      git -C $config_dir submodule deinit $path
      git -C $config_dir rm $path
    end
    # TODO: remove this directory independent of git removal? 
    if string match --invert -r $safe_path_regex $package ^/dev/null >/dev/null
      set -l dir_to_delete "$config_dir/.git/modules/$package"
      test -d $dir_to_delete; and rm -rf $dir_to_delete; and echo $package
    end
  end
   
  
  set -l usage "usage: pack i[nstall] [<name>...]
     pack remove [<name>...]
     pack list"
  
  argparse --name='pack' 'h/help' 'v/verbose' -- $argv
  
  set -q _flag_help; and echo $usage; and return 0
 
  test (count $argv) -eq 0; and echo $usage; and return 1
  
  # TODO: check for environment variable?
  set -l config_dir (string split ',' (vim --cmd 'echo &rtp|q' 2>&1))[1]
  if not test -d $config_dir
    echo (set_color red)ERROR(set_color normal) \
      could not find vim configuration directory 1>&2
    return 1
  end
  
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
    case ls list status
      __list $config_dir $_flag_verbose
    case '*'
      echo $usage
      return 1
  end
end

