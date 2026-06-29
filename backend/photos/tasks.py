from celery import shared_task

from photos.services import analyze_photo_analysis


@shared_task(
    autoretry_for=(Exception,),
    retry_backoff=True,
    retry_kwargs={"max_retries": 2},
)
def analyze_photo_analysis_task(photo_analysis_id: str):
    analyze_photo_analysis(photo_analysis_id)
