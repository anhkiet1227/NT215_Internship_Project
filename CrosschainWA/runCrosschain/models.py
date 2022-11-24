from django.db import models

# Create your models here.
class Transition(models.Model):
    BlockNumber = models.IntegerField()
    time = models.IntegerField()
    hexTrans = models.CharField(max_length=150)
    loadTrans = models.CharField(max_length=550)
