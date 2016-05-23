require File.join(File.dirname(__FILE__), '..', 'vcsrepo')

Puppet::Type.type(:vcsrepo).provide(:svn, :parent => Puppet::Provider::Vcsrepo) do
  desc "Supports Subversion repositories"

  commands :svn      => 'svn',
           :svnadmin => 'svnadmin',
           :svnlook  => 'svnlook'

  has_features :filesystem_types, :reference_tracking, :basic_auth, :configuration, :conflict, :depth

  def create
    if !@resource.value(:source) && !@resource.value(:filename)
      create_repository(@resource.value(:path))
    else
      checkout_repository(@resource.value(:source),
                          @resource.value(:path),
                          @resource.value(:revision),
                          @resource.value(:depth))
    end
    update_owner
  end

  def working_copy_exists?
    if File.directory?(@resource.value(:path))
      # :path is an svn checkout
      return true if File.directory?(File.join(@resource.value(:path), '.svn'))
      if File.file?(File.join(@resource.value(:path), 'format'))
        # :path is an svn server
        return true if svnlook('uuid', @resource.value(:path))
      end
    end
    false
  end

  def exists?
    working_copy_exists?
  end

  def destroy
    FileUtils.rm_rf(@resource.value(:path))
  end

  def latest?
    at_path do
      (self.revision >= self.latest) and (@resource.value(:source) == self.sourceurl)
    end
  end

  def buildargs
    args = ['--non-interactive']
    if @resource.value(:basic_auth_username) && @resource.value(:basic_auth_password)
      args.push('--username', @resource.value(:basic_auth_username))
      args.push('--password', @resource.value(:basic_auth_password))
      args.push('--no-auth-cache')
      args.push('--trust-server-cert')
    end

    if @resource.value(:force)
      args.push('--force')
    end

    if @resource.value(:configuration)
      args.push('--config-dir', @resource.value(:configuration))
    end

    if @resource.value(:trust_server_cert) != :false
      args.push('--trust-server-cert')
    end

    args
  end

  def latest
    args = buildargs.push('info', '-r', 'HEAD')
    at_path do
      svn(*args)[/^Revision:\s+(\d+)/m, 1]
    end
  end

  def sourceurl
    args = buildargs.push('info')
    at_path do
      svn(*args)[/^URL:\s+(\S+)/m, 1]
    end
  end

  def revision
    args = buildargs.push('info')
    at_path do
      svn(*args)[/^Revision:\s+(\d+)/m, 1]
    end
  end

  def revision=(desired)
    args = if @resource.value(:source)
             buildargs.push('switch', '-r', desired, @resource.value(:source))
           else
             buildargs.push('update', '-r', desired)
           end

    if @resource.value(:conflict)
      args.push('--accept', @resource.value(:conflict))
    end

    at_path do
      svn(*args)
    end
    update_owner
  end

  private

  def checkout_repository(source, path, revision)
	has_should = [:export, :filename, :sparse ].select { |param| @resource.value(param) == :true }
    if has_should.length > 1
      raise Puppet::Error, "You cannot specify #{has_should.join(" and ")} on this action (only one)"
    elsif @resource.value(:export)
      args = buildargs.push('export')
    elsif @resource.value(:sparse)
      args = buildargs.push('checkout')
      args.push('--depth=empty')
    elsif @resource.value(:filename)
      args = buildargs.push('up')
      args.push(@resource.value(:filename))
    else
      args = buildargs.push('checkout')
    end
    if revision
      args.push('-r', revision)
    end
    if depth
      args.push('--depth', depth)
    end
    args.push(source, path)
    svn(*args)
  end

  def create_repository(path)
    args = ['create']
    if @resource.value(:fstype)
      args.push('--fs-type', @resource.value(:fstype))
    end
    args << path
    svnadmin(*args)
  end

  def update_owner
    if @resource.value(:owner) or @resource.value(:group) or @resource.value(:mode)
      set_ownership
    end
  end
end
