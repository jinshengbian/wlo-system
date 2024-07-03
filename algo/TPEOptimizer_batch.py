
from __future__ import annotations

import time

import ConfigSpace as CS
import ConfigSpace.hyperparameters as CSH

import numpy as np

from tpe.optimizer import TPEOptimizer
from tpe.optimizer.base_optimizer import BestUpdateFunc, ObjectiveFunc, default_best_update
from tpe.utils.constants import default_percentile_maker
from tpe.utils.utils import get_logger, get_random_sample, revert_eval_config, store_results


class TPEOptimizer_batch(TPEOptimizer):
    def __init__(
        self,  
        batch_size: int,
        obj_func: ObjectiveFunc, 
        config_space: CS.ConfigurationSpace, 
        resultfile: str = "temp", 
        n_init: int = 10, 
        max_evals: int = 100, 
        seed: int | None = None, 
        metric_name: str = "loss", 
        runtime_name: str = "iter_time", 
        only_requirements: bool = False, 
        n_ei_candidates: int = 24, 
        result_keys: list[str] | None = None, 
        min_bandwidth_factor: float = 0.1, 
        top: float = 1, 
        percentile_func_maker = default_percentile_maker
    ):
        result_keys = result_keys if result_keys is not None else [metric_name]
        super().__init__(
            obj_func=obj_func, 
            config_space=config_space, 
            resultfile=resultfile, 
            n_init=n_init, 
            max_evals=max_evals, 
            seed=seed, 
            metric_name=metric_name, 
            runtime_name=runtime_name, 
            only_requirements=only_requirements, 
            n_ei_candidates=n_ei_candidates, 
            result_keys=result_keys, 
            min_bandwidth_factor=min_bandwidth_factor, 
            top=top, 
            percentile_func_maker=percentile_func_maker
            )
        self.batch_size = batch_size
    def optimize(self, logger_name: str | None = None, best_update: BestUpdateFunc = ...) -> tuple[dict[str, Any], float]:
        """
        Optimize obj_func using TPE Sampler and store the results in the end.

        Args:
            logger_name (str | None):
                The name of logger to write the intermediate results

        Returns:
            best_config (dict[str, Any]): The configuration that has the best loss
            best_loss (float): The best loss value during the optimization
        """
        use_logger = logger_name is not None
        logger_name = logger_name if use_logger else "temp"
        assert isinstance(logger_name, str), "MyPy redefinition."
        logger = get_logger(logger_name, logger_name, disable=(not use_logger))
        best_config, best_loss, t = {}, np.inf, 0
        stuck_cnt = 0
        while True:
            logger.info(f"\nIteration: {t + 1}")
            
            start = time.time()
            eval_config = self.initial_sample() if t < self._n_init else self.sample()
            time2sample = time.time() - start
            w = 0.4 if t<self._max_evals*0.4 else 0
            if t > self._n_init:
                for key,value in eval_config.items():
                    eval_config[key] = int(best_config[key]*(w)+eval_config[key]*(1-w))
            config_batch = np.array([list(eval_config.values())])
            t += 1
            for i in range(self.batch_size-1):
                eval_config = self.initial_sample() if t < self._n_init else self.sample()
                time2sample = time.time() - start
                if t > self._n_init:
                    # w = w*(i+1)/self.batch_size
                    w = w
                    for key,value in eval_config.items():
                        eval_config[key] = int(best_config[key]*(w)+eval_config[key]*(1-w))
                config_batch = np.append(config_batch,np.array([list(eval_config.values())]),axis=0)
                t += 1
            # print("Configs are:",config_batch)
            # print("=================",t,"==================")
            results_batch, runtime = self._obj_func(config_batch)
            # print("Result batch:",results_batch)
            # need to do, 
            eval_config = {}
            results = {}
            for i in range(self.batch_size):
                for j in range(len(config_batch[0,:])):
                    eval_config[f"x{j}"] = config_batch[i,j].astype(float)
                    results["loss"] = results_batch[i]
                self.update(eval_config=eval_config,results=results,runtime=runtime+time2sample)
                loss = results[self._metric_name]
            

                if loss < best_loss:
                    best_loss = loss
                    best_config = eval_config
                    stuck_cnt = 0
                else:
                    stuck_cnt += 1

                logger.info(f"Cur. loss: {loss:.4e}, Cur. Config: {eval_config}")
                logger.info(f"Best loss: {best_loss:.4e}, Best Config: {best_config}")
                

            if t >= self._max_evals:
                break

        observations = self.fetch_observations()
        logger.info(f"Best loss: {best_loss:.4e}")
        store_results(
            best_config=best_config,
            logger=logger,
            observations=observations,
            file_name=self.resultfile,
            requirements=self._requirements,
        )

        return best_config, best_loss
    