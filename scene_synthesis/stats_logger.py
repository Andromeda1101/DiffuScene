"""Stats logger provides a method for logging training stats."""
import sys

import wandb


class AverageAggregator(object):
    def __init__(self):
        self._value = 0
        self._count = 0

    @property
    def value(self):
        return self._value / self._count

    @value.setter
    def value(self, val):
        self._value += val
        self._count += 1


class StatsLogger(object):
    __INSTANCE = None

    def __init__(self):
        if StatsLogger.__INSTANCE is not None:
            raise RuntimeError("StatsLogger should not be directly created")

        self._values = dict()
        self._loss = AverageAggregator()
        self._output_files = [sys.stdout]

    def add_output_file(self, f):
        self._output_files.append(f)

    def __getitem__(self, key):
        if key not in self._values:
            self._values[key] = AverageAggregator()
        return self._values[key]

    def clear(self):
        self._values.clear()
        self._loss = AverageAggregator()
        for f in self._output_files:
            if f.isatty():
                print(file=f, flush=True)

    def print_progress(self, epoch, batch, loss, precision="{:.5f}"):
        self._loss.value = loss
        fmt = "epoch: {} - batch: {} - loss: " + precision
        msg = fmt.format(epoch, batch, self._loss.value)
        for k,  v in self._values.items():
            msg += " - " + k + ": " + precision.format(v.value)
        for f in self._output_files:
            if f.isatty():
                print(msg + "\b"*len(msg), end="", flush=True, file=f)
            else:
                print(msg, flush=True, file=f)

    @classmethod
    def instance(cls):
        if StatsLogger.__INSTANCE is None:
            StatsLogger.__INSTANCE = cls()
        return StatsLogger.__INSTANCE


class WandB(StatsLogger):
    """Log the metrics in weights and biases. Code adapted from
    https://github.com/angeloskath/pytorch-boilerplate/blob/main/pbp/callbacks/wandb.py

    Arguments
    ---------
        project: str, the project name to use in weights and biases
                 (default: '')
        watch: bool, use wandb.watch() on the model (default: True)
        log_frequency: int, the log frequency passed to wandb.watch
                       (default: 10)
        log_gradients: bool, log model gradients (default: False)
        tags: list of str, tags to add to the run (default: None)
    """
    def init(
        self,
        experiment_arguments,
        model,
        project="experiment",
        name="experiment_name",
        watch=True,
        log_frequency=10,
        log_gradients=False,
        tags=None
    ):
        self.project = project
        self.experiment_name = name
        self.watch = watch
        self.log_frequency = log_frequency
        self.log_gradients = log_gradients
        self._epoch = 0
        self._validation = False
        self._batch_counter = 0
        
        # Prepare config from experiment arguments
        config_dict = dict(experiment_arguments.items())
        
        # Login to wandb
        wandb.login()

        # Init the run
        wandb.init(
            project=(self.project or None),
            name=(self.experiment_name or None),
            config=config_dict,
            tags=tags
        )

        if self.watch:
            wandb.watch(
                model, 
                log_freq=self.log_frequency,
                log="gradients" if log_gradients else "parameters"
            )

    def print_progress(self, epoch, batch, loss, precision="{:.5f}"):
        super().print_progress(epoch, batch, loss, precision)

        self._validation = epoch < 0
        if not self._validation:
            self._epoch = epoch
        
        self._batch_counter += 1

    def log_custom_metrics(self, metrics_dict):
        """Log custom metrics to wandb.
        
        Arguments
        ---------
            metrics_dict: dict, dictionary of metric names to values
        """
        if metrics_dict:
            wandb.log(metrics_dict)

    def log_learning_rate(self, learning_rate):
        """Log learning rate to wandb.
        
        Arguments
        ---------
            learning_rate: float, current learning rate
        """
        wandb.log({"learning_rate": learning_rate})

    def log_histogram(self, name, values):
        """Log histogram of values to wandb.
        
        Arguments
        ---------
            name: str, name of the histogram
            values: tensor or numpy array, values to log
        """
        wandb.log({name: wandb.Histogram(values)})

    def clear(self):
        # Before clearing everything out send it to wandb
        prefix = "val_" if self._validation else "train_"
        values = {
            prefix+k: v.value
            for k, v in self._values.items()
        }
        values[prefix+"loss"] = self._loss.value
        values[prefix+"epoch"] = self._epoch
        values["batch_count"] = self._batch_counter
        
        wandb.log(values)

        super().clear()
    
    def finish(self):
        """Finish the wandb run."""
        wandb.finish()
