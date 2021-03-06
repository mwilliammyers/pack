function pack -d 'vim8/neovim package manager using git submodules'
    function __install -a 'config_dir' 'package' 'package_type' 'post_install_do'
        set -l repo (string split -r '/' $package)
        set -l package_dir pack/gitmodules/$package_type/$repo[2]
        
        git -C $config_dir submodule add \
            --name $package \
            --depth 1 -- \
            https://github.com/$package.git \
            $package_dir
        and git -C $config_dir config -f .gitmodules submodule.$package.shallow true
        and git -C $config_dir config -f .gitmodules submodule.$package.ignore dirty

        pushd "$config_dir"/"$package_dir"
        and eval $post_install_do
        popd

        # git -C $config_dir add .gitmodules
        # git -C $config_dir commit -m "Add $package package"
    end

    function __update -a 'config_dir'
        git -C $config_dir submodule update --jobs=0 --remote --depth=1 --init --checkout
    end

    function __list -a 'config_dir' 'is_verbose'
        if test -z $is_verbose
            set pattern '(^submodule\.|\.path\s+.*$)'
        else
            set pattern '(^submodule\.|\.path)'
        end
        
        git -C $config_dir config -f .gitmodules --get-regexp path \
            | string replace -ar $pattern ''
    end

    function __remove -a 'config_dir' 'package'
        # TODO: safe to assume it will be in config file?
        set -l path (git -C $config_dir config -f .gitmodules "submodule.$package.path")

        if test -n "$path"; and git -C $config_dir ls-files --error-unmatch $path > /dev/null 2>&1
            git -C $config_dir submodule deinit -f $path
            and rm -rf "$config_dir/.git/modules/$package"
            and git -C $config_dir rm -rf $path
            and echo ""
        end
    end


    set -l usage "usage: pack i[nstall] [<name>...]
     pack remove [<name>...]
     pack list"

    argparse --name='pack' 'h/help' 'v/verbose' 'd/do=' 'o/opt' -- $argv
    
    set -q _flag_help
    and echo $usage
    and return 0

    test (count $argv) -eq 0
    and echo $usage
    and return 1

    # TODO: check for environment variable instead?
    # TODO: faster way to do this?
    set -l config_dir
    set -l cmd 'echo split(&rtp, ",")[0] | q' 
    if command -sq nvim
        set config_dir (nvim --headless --cmd "$cmd" 2>&1)
    else if command -sq vim
        set config_dir (vim -T dumb --not-a-term --cmd "$cmd" 2>&1)
    end

    if not test -d "$config_dir"
        echo (set_color red)ERROR(set_color normal) could not find vim configuration directory 1>&2
        return 1
    end

    switch $argv[1]
        case i install a add
            set -l package_type "start"
            set -q _flag_opt; and set -l package_type "opt"

            for package in $argv[2..-1]
                # TODO: $_flag_do per package instead of the same for every package
                __install $config_dir $package $package_type $_flag_do
            end
        case up update upgrade
            __update $config_dir
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
