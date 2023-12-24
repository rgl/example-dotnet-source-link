using System;
using ExampleLibrary;

namespace ExampleApplication
{
    class Program
    {
        static void Main(string[] args)
        {
            Console.WriteLine(Greeter.Greet("World"));
            Console.WriteLine("NB");
            Console.WriteLine("NB check whether the PDB was used in the following exception stack trace.");
            Console.WriteLine("NB each stack trace line must have a deterministic file name and line number.");
            Console.WriteLine("NB the path is only deterministic when building in CI (where the CI environment variable exists).");
            Console.WriteLine("NB the stack trace should look something like:");
            Console.WriteLine("NB   Unhandled exception. System.ArgumentNullException: Value cannot be null. (Parameter 'name')");
            Console.WriteLine("NB      at ExampleLibrary.Greeter.Greet(String name) in /_/ExampleLibrary/Greeter.cs:line 14");
            Console.WriteLine("NB      at ExampleApplication.Program.Main(String[] args) in /_/ExampleApplication/Program.cs:line 20");
            Console.WriteLine("NB");
            Console.WriteLine(Greeter.Greet(null)); // with null it will throw an exception to check whether the stack traces are ok.
        }
    }
}
