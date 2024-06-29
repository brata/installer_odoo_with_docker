ARG ODDO_VERSION

FROM odoo:$ODDO_VERSION

COPY --chmod=+x entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

CMD ["odoo"]