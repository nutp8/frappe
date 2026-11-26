FROM frappe/bench:latest

USER frappe
WORKDIR /home/frappe

# Match branch versions across frappe, erpnext, and education
ARG FRAPPE_BRANCH=version-15

RUN bench init --skip-redis-config-generation --frappe-branch ${FRAPPE_BRANCH} frappe-bench \
    && cd frappe-bench \
    && bench get-app --branch ${FRAPPE_BRANCH} erpnext \
    && bench get-app --branch ${FRAPPE_BRANCH} education \
    && cp -a /home/frappe/frappe-bench/sites /home/frappe/sites-seed

COPY --chown=frappe:frappe start.sh /home/frappe/start.sh
RUN chmod +x /home/frappe/start.sh

WORKDIR /home/frappe/frappe-bench
EXPOSE 8000

CMD ["/home/frappe/start.sh"]
