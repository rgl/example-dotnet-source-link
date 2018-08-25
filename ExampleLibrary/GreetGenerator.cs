using System;

namespace ExampleLibrary
{
    public static class GreetGenerator
    {
        private static readonly string[] _greetings = new[]
        {
            "Olá {0}",      // Portuguese
            "Hola {0}",     // Spanish
            "Hello {0}",    // English
            "Hallo {0}",    // German
            "Ciao {0}",     // Italian
            "Bonjour {0}",  // French
            "Namaste {0}",  // Hindi
        };

        // this comment is here just to test whether visual studio will really
        // fetch the source code from the source link document and not try to
        // decompile it somehow.
        public static string Greet(string name)
        {
            if (string.IsNullOrEmpty(name))
            {
                throw new ArgumentNullException(nameof(name));
            }

            var i = (new Random()).Next(_greetings.Length);

            return string.Format(_greetings[i], name);
        }
    }
}
