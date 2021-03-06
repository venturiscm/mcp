from systems.plugins.index import BaseProvider

import string
import json
import re


class Provider(BaseProvider('parser', 'function')):

    function_pattern = r'^\#([a-zA-Z][\_\-a-zA-Z0-9]+)\((.*?)\)\;'
    function_value_pattern = r'(?<!\#)\#\>?([a-zA-Z][\_\-a-zA-Z0-9]+\(.*?\)\;)'


    def parse(self, value):
        if not isinstance(value, str):
            return value

        standalone_function = re.search(self.function_pattern, value)
        if standalone_function and len(standalone_function.group(0)) == len(value):
            value = self.exec_function(value)
        else:
            for ref_match in re.finditer(self.function_value_pattern, value):
                function_value = self.exec_function("#{}".format(ref_match.group(1)))
                if isinstance(function_value, (list, tuple)):
                    function_value = ",".join(function_value)
                elif isinstance(function_value, dict):
                    function_value = json.dumps(function_value)

                if function_value:
                    value = value.replace(ref_match.group(0), str(function_value)).strip()
        return value

    def exec_function(self, value):
        function_match = re.search(self.function_pattern, value)
        if function_match:
            function_name = function_match.group(1)
            function_parameters = re.split(r'\s*\|\|\s*', function_match.group(2))
            for index, parameter in enumerate(function_parameters):
                parameter = parameter.lstrip("\'\"").rstrip("\'\"")
                function_parameters[index] = self.command.options.interpolate(parameter)

            function = self.command.get_provider('function', function_name)
            return function.exec(*function_parameters)

        # Not found, assume desired
        return value
