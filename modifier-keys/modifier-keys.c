/*
Outputs a string containing the names of all modifier keys which are down.

Copyright (c) 2009, 2014 Jason Jackson

This program is free software: you can redistribute it and/or modify it under the terms
of the GNU General Public License as published by the Free Software Foundation,
either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program.
If not, see <http://www.gnu.org/licenses/>.
*/

#include <stdio.h>
#include <string.h>
#include <Carbon/Carbon.h>

#define fnKey 131072

void append_output(const unsigned int modifiers, const unsigned int key, const char* keyName, char* output)
{
	if (modifiers & key)
	{
		if (strlen(output)) strcat(output, ", ");
		strcat(output, keyName);
	}
}

int main()
{
	unsigned int modifiers = GetCurrentKeyModifiers();
	//printf("%d\n", modifiers);

	char output[100];
	output[0] = '\0';

	append_output(modifiers, alphaLock, "capslock", output);
	append_output(modifiers, shiftKey, "shift", output);
	append_output(modifiers, fnKey, "fn", output);
	append_output(modifiers, controlKey, "control", output);
	append_output(modifiers, optionKey, "option", output);
	append_output(modifiers, cmdKey, "cmd", output);

	puts(output);
	return 0;
}
