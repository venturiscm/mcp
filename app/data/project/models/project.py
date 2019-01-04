
from systems import models
from data.environment import models as env

import json


class ProjectFacade(models.ModelFacade):

    def get_packages(self):
        return super().get_packages() + ['project']


    def key(self):
        return 'name'
 
    def scope(self, fields = False):
        if fields:
            return ('environment',)
        
        state = env.Environment.facade.get_curr()
        if not state:
            return False

        return { 'environment_id': state.value }


    def retrieve(self, key, **filters):
        data = super().retrieve(key, **filters)
        if data:
            data.config = json.loads(data.config)
        return data

    def store(self, key, **values):
        if 'config' in values and isinstance(values['config'], dict):
            values['config'] = json.dumps(values['config'])
            
        return super().store(key, **values)


class Project(models.AppModel):
    name = models.CharField(max_length=128)
    type = models.CharField(null=True, max_length=128)
    config = models.TextField(null=True)
       
    remote = models.CharField(null=True, max_length=256)
    reference = models.CharField(null=True, max_length=128)
 
    environment = models.ForeignKey(env.Environment, related_name='projects', on_delete=models.CASCADE)

    class Meta:
        unique_together = ('environment', 'name')
        facade_class = ProjectFacade

    def __str__(self):
        return "{} ({}:{})".format(self.name, self.type, self.name)
