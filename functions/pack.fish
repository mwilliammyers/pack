function pack -d 'vim8/neovim package manager using git submodules'
    function __install -a 'config_dir' 'package' 'package_type' 'post_install_do'
        set -l repo (string split -r '/' $package)
        set -l package_dir pack/gitmodules/$package_type/$repo[2]
        
        git -C $config_dir submodule add \
            --name $package \
            --depth 1 https://github.com/$package.git \
            $package_dir
        and git -C $config_dir config -f .gitmodules submodule.$package.shallow true
        and git -C $config_dir config -f .gitmodules submodule.$package.ignore dirty

        pushd "$config_dir"/"$package_dir"
        eval $post_install_do
        popd

        # git -C $config_dir add .gitmodules
        # git -C $config_dir commit -m "Add $package package"

        functions -e __install
    end

    function __update -a 'config_dir'
        git -C $config_dir submodule update --jobs=0 --remote --depth=1 --init --checkout

        functions -e __update
    end

    function __list -a 'config_dir' 'is_verbose'
        set -l all_packages (string replace -ar 'submodule\.|\.path| pack/.*$' '' \
          (git -C $config_dir config -f .gitmodules --get-regexp 'submodule\..*.path'))

        set -l packages ""
        set -l verbose_packages ""
        for package_status in (git -C $config_dir submodule status ^/dev/null)
            set -l info (string split ' ' $package_status)
            # TODO: does this work in all cases?
            set -l name (string split '/' $info[3])[-1]

            set -l package (string split ' ' (string match -e $name $all_packages))[1]

            set packages "$package\n$packages"
            set verbose_packages "$package\t$info\n$verbose_packages"
        end

        if test -z $is_verbose
            echo -ne $packages | sort
        else
            echo -ne $verbose_packages | sort | column -t
        end

        functions -e __list
    end

    function __remove -a 'config_dir' 'package'
        # TODO: safe to assume it will be in config file?
        set -l path (git -C $config_dir config -f .gitmodules "submodule.$package.path")
        if git ls-files --error-unmatch $path ^/dev/null >/dev/null
            git -C $config_dir submodule deinit -f $path
            and git -C $config_dir rm -rf $path
            and rm -rf "$config_dir/.git/modules/$package"
            and echo $package
        end

        functions -e __remove
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

    # TODO: check for environment variable?
    set -l config_dir (string split ',' (vim --cmd 'echo &rtp|q' 2>&1))[1]
    if not test -d $config_dir
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
