from systems.command import types, factory


class Command(
    types.LogRouterCommand
):
    def get_command_name(self):
        return 'log'

    def get_subcommands(self):
        parent = types.LogActionCommand
        base_name = 'log'
        return (
            ('list', factory.ListCommand(
                parent, base_name,
                fields = (
                    ('name', 'Name'),
                    ('user', 'User'),
                    ('command', 'Command'),
                    ('created', 'Started'),
                    ('updated', 'Finished')
                )
            )),
            ('get', factory.GetCommand(
                parent, base_name
            ))
        )