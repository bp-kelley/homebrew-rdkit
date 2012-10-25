require 'formula'

def with_java
  return ARGV.include?('--with-java')
end

def with_inchi
  return ARGV.include?('--with-inchi')
end

class Rdkit < Formula
  homepage 'http://rdkit.org/'
  url 'http://sourceforge.net/projects/rdkit/files/rdkit/Q3_2012/RDKit_2012_09_1.tgz'
  head 'http://svn.code.sf.net/p/rdkit/code/trunk/', :using=> :svn
  sha1 'cae543325dd40d8f8ed09dd58fa4504dde153382'

  depends_on 'cmake' => :build
  depends_on 'wget' => :build
  depends_on 'swig'
  depends_on 'boost'
  depends_on 'numpy' => :python

  def options
    [
      ['--with-java', "Build Java wrapper"],
      ['--with-inchi', "Build InChI support"]
    ]
  end

  def install
    # build java wrapper?
    if with_java
      if not File.exists? 'External/java_lib/junit.jar'
        system "mkdir External/java_lib"
        system "curl http://cloud.github.com/downloads/KentBeck/junit/junit-4.10.jar -o External/java_lib/junit.jar"
      end
    end
    # build inchi support?
    if with_inchi
      system "cd External/INCHI-API; bash download-inchi.sh"
    end

    args = std_cmake_parameters.split
    args << '-DRDK_INSTALL_INTREE=OFF'
    args << '-DRDK_INSTALL_STATIC_LIBS=OFF'

    args << '-DRDK_BUILD_SWIG_WRAPPERS=ON' if with_java
    args << '-DRDK_BUILD_INCHI_SUPPORT=ON' if with_inchi

    # The CMake `FindPythonLibs` Module does not do a good job of finding the
    # correct Python libraries to link to, so we help it out (until CMake is
    # fixed). This code was cribbed from the opencv formula, which took it from
    # the VTK formula. It uses the output from `python-config`.
    which_python = "python" + `python -c 'import sys;print(sys.version[:3])'`.strip
    python_prefix = `python-config --prefix`.strip
    # Python is actually a library. The libpythonX.Y.dylib points to this lib, too.
    if File.exist? "#{python_prefix}/Python"
      # Python was compiled with --framework:
      args << "-DPYTHON_LIBRARY='#{python_prefix}/Python'"
      args << "-DPYTHON_INCLUDE_DIR='#{python_prefix}/Headers'"
    else
      python_lib = "#{python_prefix}/lib/lib#{which_python}"
      if File.exists? "#{python_lib}.a"
        args << "-DPYTHON_LIBRARY='#{python_lib}.a'"
      else
        args << "-DPYTHON_LIBRARY='#{python_lib}.dylib'"
      end
      args << "-DPYTHON_INCLUDE_DIR='#{python_prefix}/include/#{which_python}'"
    end

    args << '.'
    system "cmake", *args
    ENV.j1
    system "make"
    system "make install"
    # Remove the ghost .cmake files which will cause a warning if we install them to 'lib'
    rm_f Dir["#{lib}/*.cmake"]
  end

  def patches
    DATA
  end

  def caveats
    python_lib = `python --version 2>&1| sed -e 's/Python \\([0-9]\\.[0-9]\\)\\.[0-9]/python\\1/g'`.strip

    return <<-EOS.undent
    You still have to add RDBASE to your environment variables and update
    PYTHONPATH.

    For Bash, put something like this in your $HOME/.bashrc

      export RDBASE=#{HOMEBREW_PREFIX}/share/RDKit
      export PYTHONPATH=$PYTHONPATH:#{HOMEBREW_PREFIX}/lib/#{python_lib}/site-packages

    EOS
  end
end

__END__
--- a/CMakeLists.txt  2012-10-19 23:47:44.000000000 -0700
+++ b/CMakeLists.txt	2012-10-21 23:35:13.000000000 -0700
@@ -151,6 +151,7 @@
   set(Boost_THREAD_LIBRARY )
 endif()

+find_package(Boost 1.39.0 COMPONENTS system REQUIRED)

 # setup our compiler flags:
 if(CMAKE_COMPILER_IS_GNUCXX)
--- a/Code/GraphMol/CMakeLists.txt	2012-06-29 22:27:14.000000000 -0700
+++ b/Code/GraphMol/CMakeLists.txt	2012-10-21 23:36:25.000000000 -0700
@@ -5,7 +5,7 @@
               AtomIterators.cpp BondIterators.cpp Aromaticity.cpp Kekulize.cpp
               MolDiscriminators.cpp ConjugHybrid.cpp AddHs.cpp RankAtoms.cpp
               Matrices.cpp Chirality.cpp RingInfo.cpp Conformer.cpp
-              SHARED LINK_LIBRARIES RDGeometryLib RDGeneral)
+	      SHARED LINK_LIBRARIES RDGeometryLib RDGeneral ${Boost_SYSTEM_LIBRARY})

 rdkit_headers(Atom.h
               atomic_data.h
--- a/Code/JavaWrappers/gmwrapper/CMakeLists.txt  2012-10-24 22:22:15.000000000 -0700
+++ b/Code/JavaWrappers/gmwrapper/CMakeLists.txt	2012-10-01 22:57:23.000000000 -0700
@@ -74,7 +74,7 @@

 SWIG_ADD_MODULE(GraphMolWrap "java" GraphMolJava.i )

-SWIG_LINK_LIBRARIES(GraphMolWrap ${RDKit_Wrapper_Libs} )
+SWIG_LINK_LIBRARIES(GraphMolWrap ${RDKit_Wrapper_Libs} ${Boost_SYSTEM_LIBRARY})

 # code adapted from the wrapper code for
 # GDCM: http://gdcm.svn.sf.net/viewvc/gdcm/trunk/Wrapping/Java/CMakeLists.txt?view=markup