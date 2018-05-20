using System;

namespace ExampleLibrary
{
    public static class Greeter
    {
        // this comment is here just to test whether visual studio will really
        // fetch the source code from the source link document and not try to
        // decompile it somehow.
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
