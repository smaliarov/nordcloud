*********************
Notejam: Spring & AWS
*********************

Notejam application implemented using `Spring <http://projects.spring.io/spring-framework/>`_ framework.
Adjust for AWS deployment.

Spring version: 4.2.3

The full stack is:

- `Spring Boot <http://projects.spring.io/spring-boot/>`_ (Spring configuration)
- `Thymeleaf <http://www.thymeleaf.org/>`_ (View)
- `Spring Security <http://projects.spring.io/spring-security/>`_ (Security framework)
- `Spring`_ (DI and MVC framework)
- `Spring Data <http://projects.spring.io/spring-data/>`_ (Persistence abstraction)
- `JPA <http://www.oracle.com/technetwork/java/javaee/tech/persistence-jsp-140049.html>`_ (Persistence API)
- `Hibernate <http://hibernate.org/orm/>`_ (JPA implementation)
- `Terraform`_ (Infrastructure creation)
- `AWS CodePipeline`_ (CI/CD)

==========================
Installation and launching
==========================

-----
Clone
-----

Clone the repo:

.. code-block:: bash

    $ git clone https://github.com/smaliarov/nordcloud YOUR_PROJECT_DIR/

-------
Install
-------

Install a `JDK <http://openjdk.java.net/>`_, `Maven <https://maven.apache.org/>`_ and `Terraform <https://www.terraform.io/>`_ (for cloud deployment).

-------------
Configuration
-------------

The application has a password recovery process which involves sending an email.
If you want to enable that, you have to create a local application.properties file
and set there the property spring.mail.host to your SMTP server (e.g. spring.mail.host = smtp.example.net).

.. code-block:: bash

    $ cd YOUR_PROJECT_DIR/spring/
    $ vi application.properties

See `MailProperties <http://docs.spring.io/spring-boot/docs/current/api/index.html?org/springframework/boot/autoconfigure/mail/MailProperties.html>`_
for more mail properties.

This has not been enabled for cloud deployment.

--------------
Launch locally
--------------

Compile and launch the application:

.. code-block:: bash

    $ cd YOUR_PROJECT_DIR/spring/
    $ mvn spring-boot:run

Go to http://localhost:8080/ in your browser.

~~~~~~~~~~~~
Localization
~~~~~~~~~~~~

This application comes with support for the languages German and English. The locale is
determined by the Accept-Language request header. If the header is not present the
content will be served with the default locale of the JVM. The application will not
start if the default locale is non of the supported languages.

---------
Run tests
---------

Run functional and unit tests:

.. code-block:: bash

    $ mvn test

================
Launch in cloud
================

This implementation uses Terraform for deployments. You can launch it from your local machine.

First, navigate to terraform folder.

.. code-block:: bash

    $ cd terraform/

Second, modify main.tfvars if needed. See description of all variables at variables.tf

Third, make a copy of secrets.json.example and name it secrets.json.
It's a very basic (and somewhat stupid) way of keeping private data (passwords and tokens) out of git.

Now, you need to be logged in to AWS with some user that will allow you to create all needed infrastructure. For the sake of time, I used an admin user with full access. Never do that on production!

When your config is ready and you have proper AWS credentials available on your machine, run something like

.. code-block:: bash

    $ terraform apply -var-file=main.tfvars -auto-approve

It will take some time to create all needed resources. Remember, you can easily delete all at once using terraform destroy command.

================
Choices made
================

1. Docker to pack the application into container.
2. External database (RDS).
3. Terraform so that I have infrastructure as code. Why Terraform? I have more experience with Terraform than with Ansible. I somehow like Ansible somewhat better but I thought it would be faster with Terraform.
4. ECS to run services. An alternative would be EKS, but I think that for this example ECS is simpler and easier to use.
5. I didn't connect a domain name. In this case, there should be a Route53 alias record pointing to ALB.

================
Shortcuts taken
================

Oh, where do I start...

- database password should not be stored as an environment variable. It should be stored in Parameter Store or (better) in AWS Secrets Manager (with automatic rotation).
- there should be at least 2 EC2 instances running at any time. RDS should also run in a cluster mode.
- EC2 instances created in public subnets. Should be in private.


=====================
Further improvements
=====================

0. Of course, fix all shortcuts I've taken.
1. Separate backend and frontend. You could have nicer frontend with all modern features built with Angular or React. Then backend would be able to serve more requests (because it doesn't need to serve static files like CSS or render HTML).
For this, you'll need slightly different deployment. I would deploy static files to an S3 bucket, backend would be served from ECS, then put a CloudFront distribution in front.
2. Extract email sender to a separate service that would get tasks from SQS. It will bring a lot of benefits like lesser load on backend, automatic retries, better visibility of errors there, etc.
3. Split backend into microservices - note, pad, user.