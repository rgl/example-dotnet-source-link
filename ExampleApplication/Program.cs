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
