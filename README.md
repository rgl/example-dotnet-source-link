This in an example nuget library and application that uses [source link](https://github.com/dotnet/core/blob/master/Documentation/diagnostics/source_link.md) and embedded [portable pdbs](https://github.com/dotnet/core/blob/master/Documentation/diagnostics/portable_pdb.md) to be able to step into a nuget package source code.


# Notes

* To be able to step into a nuget package source code you need to configure Visual Studio as:
  * Select `Tools` | `Options` | `Debugging` | `General`
  * Uncheck `Enable Just my Code`
* To be able to access a private GitLab server that requires authentication you need to [configure the GitLab server and Visual Studio](https://github.com/rgl/gitlab-source-link-proxy).


# Caveats

* Since this uses portable pdbs you need .NET Framework 4.7.1+ to have file names and line numbers in stack traces.
* There is no way to include the pdbs in the main nupkg. the nuget `--include-symbols` command line
  argument always creates a second package.
  See https://github.com/NuGet/Home/issues/4142
* In a future release of dotnet, it seems we'll have properties to include the symbols in the main package.
  See `IncludeSymbolsInPackage` and `CreatePackedPackage` at https://github.com/dotnet/buildtools/blob/master/src/Microsoft.DotNet.Build.Tasks.Packaging/src/NuGetPack.cs


# Reference

* [Customize your build](https://docs.microsoft.com/en-us/visualstudio/msbuild/customize-your-build)
* [dotnet pack](https://docs.microsoft.com/en-us/dotnet/core/tools/dotnet-pack?tabs=netcore2x)
* [dotnet sourcelink](https://github.com/dotnet/sourcelink)
* [ctaggart/SourceLink](https://github.com/ctaggart/SourceLink)


# Example

Configure msbuild to always use SourceLink:

```bash
cat >Directory.Build.props <<'EOF'
<Project>
  <ItemGroup>
    <!-- NB for GitLab you need to switch the PackageReference to Microsoft.SourceLink.GitLab. -->
    <PackageReference Include="Microsoft.SourceLink.GitHub" Version="1.1.1" PrivateAssets="All" />
  </ItemGroup>
</Project>
EOF
```

Configure nuget to use our local directory as a package source:

```bash
cat >NuGet.Config <<'EOF'
<configuration>
  <packageSources>
    <add key="ExampleLibrary" value="ExampleLibrary" />
  </packageSources>
</configuration>
EOF
```

Create a new library project:

```bash
mkdir ExampleLibrary
cd ExampleLibrary
dotnet new classlib
rm Class1.cs
cat >Greeter.cs <<'EOF'
using System;

namespace ExampleLibrary
{
    public static class Greeter
    {
        public static string Greet(string name)
        {
            if (string.IsNullOrEmpty(name))
            {
                throw new ArgumentNullException(nameof(name));
            }
            return $"Hello {name}!";
        }
    }
}
EOF
# configure the C# compiler to embed the portable pdb inside the dll.
# NB portable pdbs are supported by .NET Core 2+ and .NET Framework 4.7.1+.
cat >ExampleLibrary.csproj <<'EOF'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>netstandard2.0</TargetFramework>
    <DebugType>embedded</DebugType>
  </PropertyGroup>
</Project>
EOF
cd ..
```

Create a console application that references the `ExampleLibrary` package:

```bash
mkdir ExampleApplication
cd ExampleApplication
dotnet new console
dotnet add package ExampleLibrary --version 0.0.3 --no-restore
cat >Program.cs <<'EOF'
using System;
using ExampleLibrary;

namespace ExampleApplication
{
    class Program
    {
        static void Main(string[] args)
        {
            Console.WriteLine(Greeter.Greet("World"));
            Console.WriteLine(Greeter.Greet(null)); // with null it will throw an exception to check whether the stack traces are ok.
        }
    }
}
EOF
# configure the C# compiler to embed the portable pdb inside the exe.
# NB portable pdbs are supported by .NET Core 2+ and .NET Framework 4.7.1+.
cat >ExampleApplication.csproj <<'EOF'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net6.0</TargetFramework>
    <DebugType>embedded</DebugType>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="ExampleLibrary" Version="0.0.3" />
  </ItemGroup>
</Project>
EOF
cd ..
```

Commit and push the code:

```bash
cat >.gitignore <<'EOF'
bin/
obj/
*.nupkg
*.tmp
EOF
git init
git add .
git commit -m init
git remote add origin https://github.com/rgl/example-dotnet-source-link.git
git push -u origin master
```

Build the library and its nuget:

```bash
cd ExampleLibrary
dotnet build -v:n -c:Release
dotnet pack -v:n -c=Release --no-build -p:PackageVersion=0.0.3 --output .
```

Verify that the source links within the files inside the `.nupkg` work:

```bash
dotnet tool install --global sourcelink
choco install -y jq
sourcelink test ExampleLibrary.0.0.3.nupkg
rm -rf ExampleLibrary.0.0.3.nupkg.tmp && 7z x -oExampleLibrary.0.0.3.nupkg.tmp ExampleLibrary.0.0.3.nupkg
sourcelink print-urls ExampleLibrary.0.0.3.nupkg.tmp/lib/netstandard2.0/ExampleLibrary.dll
sourcelink print-json ExampleLibrary.0.0.3.nupkg.tmp/lib/netstandard2.0/ExampleLibrary.dll | cat | jq .
sourcelink print-documents ExampleLibrary.0.0.3.nupkg.tmp/lib/netstandard2.0/ExampleLibrary.dll
```

Build the example application that uses the nuget:

```bash
cd ../ExampleApplication
dotnet build -v:n -c:Release
sourcelink print-urls bin/Release/net6.0/ExampleApplication.dll
sourcelink print-json bin/Release/net6.0/ExampleApplication.dll | cat | jq .
sourcelink print-documents bin/Release/net6.0/ExampleApplication.dll
dotnet run -v:n -c=Release --no-build
```

You should see file name and line numbers in all the stack trace lines. e.g.:

```
Unhandled Exception: System.ArgumentNullException: Value cannot be null.
Parameter name: name
   at ExampleLibrary.Greeter.Greet(String name) in C:\vagrant\Projects\example-dotnet-source-link\ExampleLibrary\Greeter.cs:line 14
   at ExampleApplication.Program.Main(String[] args) in C:\vagrant\Projects\example-dotnet-source-link\ExampleApplication\Program.cs:line 10
```
